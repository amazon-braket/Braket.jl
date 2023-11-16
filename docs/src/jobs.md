# Amazon Braket Hybrid Jobs 

Amazon Braket Hybrid Jobs allow you to easily run hybrid classical-quantum workflows on AWS managed infrastructure by submitting your own scripts which run in a Docker container, either one provided by Amazon Braket or one that is made available to you through Amazon ECR. To learn more about Amazon Braket Hybrid Jobs, see the [Developer Guide](https://docs.aws.amazon.com/braket/latest/developerguide/braket-jobs.html), and to learn how to provide your own Docker images, see the [Bring Your Own Container (BYOC) guide](https://docs.aws.amazon.com/braket/latest/developerguide/braket-jobs-byoc.html).

You can also run a [`LocalJob`](https://docs.aws.amazon.com/braket/latest/developerguide/braket-jobs-local-mode.html), which runs the container and your script on your compute hardware (your laptop, or an EC2 instance, for example), using `LocalQuantumJob`. This can be useful for debugging and performance tuning purposes.

```@docs
Job
AwsQuantumJob
LocalQuantumJob
AwsQuantumJob(::String, ::String)
LocalQuantumJob(::String, ::String)
log_metric
metrics
logs
download_result
@hybrid_job
```
