kubectl exec $1 -- sh -c "cd logs; cat everything.log; (bash || ash || sh)"
