package com.example.dlqscripts;

import com.google.common.util.concurrent.RateLimiter;
import lombok.Builder;
import lombok.Data;
import org.apache.commons.lang3.tuple.Triple;
import software.amazon.awssdk.auth.credentials.AwsCredentialsProvider;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.core.client.config.ClientOverrideConfiguration;
import software.amazon.awssdk.http.SdkHttpClient;
import software.amazon.awssdk.http.apache.ApacheHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.DeleteMessageBatchRequest;
import software.amazon.awssdk.services.sqs.model.DeleteMessageBatchRequestEntry;
import software.amazon.awssdk.services.sqs.model.DeleteMessageBatchResponse;
import software.amazon.awssdk.services.sqs.model.Message;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageResponse;
import software.amazon.awssdk.services.sqs.model.SendMessageBatchRequest;
import software.amazon.awssdk.services.sqs.model.SendMessageBatchRequestEntry;
import software.amazon.awssdk.services.sqs.model.SendMessageBatchResponse;

import java.io.File;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Function;
import java.util.stream.Collectors;

@Data
@Builder
public class DlqHandler {

    private static final int SQS_BATCH_SIZE = 10;
    private static final int SQS_WAIT = 5;

    private Region awsRegion;
    private String dlqQueue;
    private String replayQueue;
    private int threads;
    private long maxMessages;
    private int messageVisibility;
    @Builder.Default
    private int replayMessageDelay = 0;
    private RateLimiter replayRateLimit;
    private Function<Message, Action> messageHandler;
    @Builder.Default
    private Function<String, String> replayMessageAdapter = Function.identity();

    public void run() throws Exception {
        System.out.println("Start from [" + (new File(".").getAbsolutePath()) + "]");

        // SQS Client & Queue
        ApacheHttpClient.Builder httpClientBuilder = ApacheHttpClient.builder()
            .maxConnections(5)
            .socketTimeout(Duration.ofSeconds(30))
            .connectionTimeout(Duration.ofSeconds(30))
            .connectionAcquisitionTimeout(Duration.ofSeconds(30))
            .connectionTimeToLive(Duration.ofSeconds(30))
            .connectionMaxIdleTime(Duration.ofSeconds(30))
            .useIdleConnectionReaper(true);
        SdkHttpClient client = httpClientBuilder.build();
        AwsCredentialsProvider awsCredentialsProvider = DefaultCredentialsProvider.create();
        ClientOverrideConfiguration overrideConfiguration = ClientOverrideConfiguration.builder().build();
        SqsClient sqsClient = SqsClient.builder()
            .credentialsProvider(awsCredentialsProvider)
            .region(awsRegion)
            .overrideConfiguration(overrideConfiguration)
            .httpClient(client)
            .build();

        System.out.println("Got SQS Client");

        AtomicLong allSeen = new AtomicLong(0L);
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        List<Future<Triple<Long, Long, Long>>> futures = new ArrayList<>();
        for (int i = 0; i < threads; i++) {
            futures.add(executor.submit(() -> handleMessages(sqsClient, allSeen)));
        }
        Long seen = 0L;
        Long replayed = 0L;
        Long deleted = 0L;
        for (int i = 0; i < threads; i++) {
            Triple<Long, Long, Long> threadComplete = futures.get(i).get();
            seen += threadComplete.getLeft();
            replayed += threadComplete.getMiddle();
            deleted += threadComplete.getRight();
        }

        System.out.println(
            System.currentTimeMillis()
                + " : Complete : "
                + " Seen [" + seen + "]"
                + " Replayed [" + replayed + "]"
                + " Deleted [" + deleted + "]"
        );


        sqsClient.close();

        System.out.println("Done");
    }

    private Triple<Long, Long, Long> handleMessages(SqsClient sqsClient, AtomicLong allSeen) throws Exception {
        boolean done = false;
        long threadSeen = 0L;
        long threadReplayed = 0L;
        long threadDeleted = 0L;


        List<Message> replayDlqMessages = new LinkedList<>();
        List<Message> deleteDlqMessages = new LinkedList<>();
        while (!done && ((maxMessages < 0) || (allSeen.get() < maxMessages))) {
            ReceiveMessageResponse receiveResponse = sqsClient.receiveMessage(
                ReceiveMessageRequest.builder()
                    .queueUrl(dlqQueue)
                    .maxNumberOfMessages(SQS_BATCH_SIZE)
                    .waitTimeSeconds(SQS_WAIT)
                    .visibilityTimeout(messageVisibility)
                    .build()
            );

            if (!receiveResponse.hasMessages()) {
                done = true;
            } else {
                for (Message dlqMessage : receiveResponse.messages()) {
                    Action action = messageHandler.apply(dlqMessage);
                    if (Action.SKIP.equals(action)) {
                        // do nothing
                    } else if (Action.REPLAY.equals(action)) {
                        replayDlqMessages.add(dlqMessage);
                    } else if (Action.DELETE.equals(action)) {
                        deleteDlqMessages.add(dlqMessage);
                    }
                }

                if (!deleteDlqMessages.isEmpty()) {
                    // delete from DLQ
                    DeleteMessageBatchResponse deleteResponse = sqsClient.deleteMessageBatch(
                        DeleteMessageBatchRequest.builder()
                            .queueUrl(dlqQueue)
                            .entries(deleteDlqMessages.stream()
                                .map(m -> DeleteMessageBatchRequestEntry.builder()
                                    .id(m.messageId())
                                    .receiptHandle(m.receiptHandle())
                                    .build())
                                .collect(Collectors.toList()))
                            .build()
                    );
                    if (deleteResponse.hasFailed()) {
                        throw new RuntimeException("Failed to delete messages " + deleteResponse.failed());
                    }
                }

                // Replay to main queue - not known as bad
                if (!replayDlqMessages.isEmpty()) {
                    // Acquire Send rate limit
                    replayRateLimit.acquire(replayDlqMessages.size());
                    // Replay to main queue
                    SendMessageBatchResponse sendResponse = sqsClient.sendMessageBatch(
                        SendMessageBatchRequest.builder()
                            .queueUrl(replayQueue)
                            .entries(replayDlqMessages.stream()
                                .map(m -> {
//                                    System.out.println("Message is " + m.toString());
//                                    System.out.println("MessageGroup is " + m.messageAttributes().get("MessageGroupId"));
//                                    System.out.println("MessageAttrs is " + m.messageAttributes());
//                                    System.out.println("MessageSysAttrs is " + m.attributes());
                                        String messageGroupId = UUID.randomUUID().toString();
                                        return SendMessageBatchRequestEntry.builder()
                                            .id(m.messageId())
                                            .messageBody(replayMessageAdapter.apply(m.body()))
                                            .messageGroupId(messageGroupId)
                                            .delaySeconds(replayMessageDelay)
                                            .build();
                                    }
                                )
                                .collect(Collectors.toList()))
                            .build()
                    );
                    if (sendResponse.hasFailed()) {
                        throw new RuntimeException("Failed to replay messages " + sendResponse.failed());
                    }

                    // delete from DLQ once replayed
                    DeleteMessageBatchResponse deleteResponse = sqsClient.deleteMessageBatch(
                        DeleteMessageBatchRequest.builder()
                            .queueUrl(dlqQueue)
                            .entries(replayDlqMessages.stream()
                                .map(m -> DeleteMessageBatchRequestEntry.builder()
                                    .id(m.messageId())
                                    .receiptHandle(m.receiptHandle())
                                    .build())
                                .collect(Collectors.toList()))
                            .build()
                    );
                    if (deleteResponse.hasFailed()) {
                        throw new RuntimeException("Failed to delete replay messages " + deleteResponse.failed());
                    }
                }

                System.out.println(
                    System.currentTimeMillis()
                        + " :"
                        + " @ : Messages [" + allSeen.get() + "]"
                        + " of [" + maxMessages + "]"
                        + " : Replayed [" + replayDlqMessages.size() + "]"
                        + " : Deleted [" + deleteDlqMessages.size() + "]"
                );

                allSeen.addAndGet(receiveResponse.messages().size());
                threadSeen += receiveResponse.messages().size();
                threadReplayed += replayDlqMessages.size();
                threadDeleted += deleteDlqMessages.size();

                replayDlqMessages.clear();
                deleteDlqMessages.clear();
            }
        }
        return Triple.of(threadSeen, threadReplayed, threadDeleted);
    }

    public enum Action {
        SKIP,
        REPLAY,
        DELETE
    }
}
