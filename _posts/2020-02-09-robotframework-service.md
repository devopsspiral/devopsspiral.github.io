---
layout: page
#
# Content
#

title: "Testing on kubernetes - rf-service"
teaser: "In this article I'm showing how to run robotframework tests from k8s cluster."
header:
  background-color: "#4472c4"
  image: logo_colors.svg
  title: DevOps Spiral
categories:
  - articles
  - k8s
tags:
  - testing
  - kubernetes
  - RobotFramework

image:
  homepage: "robotframework-service.jpg"
  thumb: "robotframework-service.jpg"
  header: "robotframework-service.jpg"
  title: "robotframework-service.jpg"
  caption: 'Image by <a href="https://pixabay.com/users/TeroVesalainen-809550/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=2077018">TeroVesalainen</a> from <a href="https://pixabay.com/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=2077018">Pixabay</a>'
---
As mentioned in my previous article about [Robot Framework library for testing Kubernetes](https://devopsspiral.com/articles/k8s/robotframework-kubelibrary/) I pointed out that it would be really great to run robot tests from within the k8s cluster. This way tests created as acceptance stage could become health checks. The problem with production environments is that their state is drifting. There are many techniques that puts the changes on live environment into harness like gitops, but the only way to be sure that your cluster has the configuration you expect is to simply check it. In this article I'm showing simple service (k8s CronJob) that is executing given tests on defined schedule and publishes them on http server.

<div class="panel radius" markdown="1">
**Table of Contents**
{: #toc }
*  TOC
{:toc}
</div>

## The goal

What I wanted to achieve is stateless service that can execute set of tests provided somehow and publish results somewhere. Somehow and somewhere can be anything that implements defined abstract classes. By the way, you can find rf-service code on [github](https://github.com/devopsspiral/rf-service/tree/v0.1.0). I thought the most useful small step I can take is to have tests being taken from http server as zip - same as branches are available in github for example, and test results published in local http server for which I've chosen Caddy. You could use any other tool for this job, but I just wanted to try some new stuff, especially that I heard some good things about Caddy.

As for rf-service itself, thanks to Robot Framework API you can pretty easily load tests and generate results pragmatically. So each (Cron)Job execution starts with downloading test suites into temporary context dir, then tests are executed and published on Caddy server. There is nothing left on rf-service after execution, the only outcome is HTML report accessible via Caddy that simply lists all the reports.

rf-service configuration is passed as JSON file - the only argument. This is the place to tell rf-service how exactly it should obtain tests and where to publish them. Default configuration (used in helm chart) is as follows.

{% highlight json %}
  {
    "fetcher": {
        "type": "ZipFetcher",
        "url": "https://github.com/devopsspiral/KubeLibrary/archive/incluster.zip"
    },
    "publisher": {
        "type": "CaddyPublisher",
        "url": "http://rf-service-caddy/uploads"
    }
  }
{% endhighlight %}

First we define fetcher of type ZipFetcher and passing URL with file, which happens to be example tests from [KubeLibrary repo](https://github.com/devopsspiral/KubeLibrary/tree/incluster/testcases) but made from in-cluster execution (incluster branch). Then tests will be published using CaddyPubliser which is nothing else than PUT request towards Caddy. Notice usage of Caddy kubernetes service name as host.

<small markdown="1">[Back to table of contents](#toc)</small>

## Caddy configuration

I heard about Caddy only recently and decided to give it a try. It is written in go and seems to have a lot to offer and can be alternative for tools like nginx (at least in some cases). One of things that actually differentiate it from competition is really easy and readable configuration file also known as caddyfile. In my case I will use following one.

{% highlight bash %}
  # Bind address
  :8080

  tls off
  log stdout
  errors stderr

  # After this line, all other paths are relative to root.
  root /tmp/store
  browse /


  upload /uploads {
    to "/tmp/store"
  }
{% endhighlight %}

Which instructs Caddy to expose itself on port 8080, disable https, configure logging to console, set root directory and enable browsing it and finally define endpoint for uploads. This is available only when using upload plugin which thankfully is in place in *jumanjiman/caddy* docker image I'm using in rf-service helm chart.

<small markdown="1">[Back to table of contents](#toc)</small>

## rf-service chart

Helm chart for rf-service is not very complicated, it is starting one container with Caddy with persistent volume and container with rf-service each time tests are executed. rf-service configuration JSON file is kept in configMap so you can change the configuration dynamically between test execution. You can find more detailed description of parameters in [README](https://github.com/devopsspiral/rf-service/tree/v0.1.0#helm-chart).

Very basic helm install should already bring the whole setup to your cluster. By default Caddy service is exposed as type LoadBalancer. Also keep in mind that rf-service will be using serviceAccount bound to cluster-admin role, you should create your own role to reflect only limited permissions needed for your tests.

{% highlight bash %}
git clone -b v0.1.0 https://github.com/devopsspiral/rf-service.git
cd rf-service
helm install rf-service chart/rf-service/
{% endhighlight %}

After deploying helm chart tests will be executed and published every minute. You can track the execution by observing CronJob pods that are created every minute or viewing output from Robot Framework execution in logs.

{% highlight bash %}
$ kubectl get pods
NAME                                   READY   STATUS      RESTARTS   AGE
rf-service-657fcf649d-cvtk9            1/1     Running     0          3m37s
rf-service-test-job-1581375660-4d4jt   0/1     Completed   0          2m36s
rf-service-test-job-1581375720-wmdsj   0/1     Completed   0          96s
rf-service-test-job-1581375780-2x2fn   0/1     Completed   0          36s
{% endhighlight %}

Other than that each test result should be published on Caddy and look similar to below.

![Tests results in Caddy](/images/robotframework-service/test-results.png)

<small markdown="1">[Back to table of contents](#toc)</small>

## Conclusion

This short article described how to run Robot Framework tests along with KubeLibrary from within your cluster. The whole configuration is static on one side, but allows some dynamic changes like rf-service configuration through configMap or update of tests in git branch. To make it even more dynamic rf-service should become RESTful, which would allow running tests on demand with different configuration per each execution.



<small markdown="1">[Back to table of contents](#toc)</small>

