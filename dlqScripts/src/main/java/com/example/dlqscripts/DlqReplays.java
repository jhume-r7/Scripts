package com.example.dlqscripts;

import com.google.common.util.concurrent.RateLimiter;
import software.amazon.awssdk.regions.Region;

import java.util.concurrent.atomic.AtomicInteger;

public class DlqReplays {

    // ENV VARS : AWS_PROFILE=awsaml-331120747613;AWS_DEFAULT_PROFILE=awsaml-331120747613
    // ENV VARS : AWS_PROFILE=awsaml-977491976143;AWS_DEFAULT_PROFILE=awsaml-977491976143

//    public static final Region AWS_REGION = Region.US_EAST_1;
    public static final Region AWS_REGION = Region.AP_SOUTHEAST_2;
    private static final String SQS_QUEUE_MAIN_URL =
//        "https://sqs.us-east-1.amazonaws.com/977491976143/proton-staging-1-pending-alert-change-notification-queue.fifo";
        "https://sqs.ap-southeast-2.amazonaws.com/977491976143/proton-staging-4-pending-alert-change-notification-queue.fifo";
    private static final String SQS_QUEUE_DLQ_URL =
//        "https://sqs.us-east-1.amazonaws.com/977491976143/proton-staging-1-pending-alert-change-notification-queue-dlq.fifo";
        "https://sqs.ap-southeast-2.amazonaws.com/977491976143/proton-staging-4-pending-alert-change-notification-queue-dlq.fifo";
    private static final int SQS_VISIBILITY_TIMEOUT_PER_MESSAGE = 60;
    private static final int SQS_REPLAY_DELAY_PER_MESSAGE = 0;

    public static final RateLimiter SQS_SEND_MESSAGES_RATE_LIMITER = RateLimiter.create(500);
    public static final int MAX_MESSAGES = -1;
    public static final int THREADS = 20;

    public static void main(String[] args) throws Exception {
        AtomicInteger index = new AtomicInteger(0);

        DlqHandler dlqHandler = DlqHandler.builder()
            .awsRegion(AWS_REGION)
            .dlqQueue(SQS_QUEUE_DLQ_URL)
            .replayQueue(SQS_QUEUE_MAIN_URL)
            .threads(THREADS)
            .maxMessages(MAX_MESSAGES)
            .messageVisibility(SQS_VISIBILITY_TIMEOUT_PER_MESSAGE)
            .replayRateLimit(SQS_SEND_MESSAGES_RATE_LIMITER)
            .replayMessageDelay(SQS_REPLAY_DELAY_PER_MESSAGE)
            .messageHandler((dlqMessage) -> {
                int currentIndex = index.getAndIncrement();
                if (currentIndex % 1000 == 0) {
                    System.out.println("Replaying at Index " + currentIndex);
                }
                return DlqHandler.Action.REPLAY;
            })
            .build();
        dlqHandler.run();

        System.out.println("Done");
    }
}
