---
layout: page
#
# Content
#

title: "Testing with octopus"
teaser: "In this article I'm describing how I made KubeLibrary, rf-service and octopus work together."
categories:
  - articles
  - k8s
tags:
  - testing
  - kubernetes
  - RobotFramework
  - Octopus

image:
  homepage: "testing_with_octopus.jpg"
  thumb: "testing_with_octopus.jpg"
  header: "testing_with_octopus.jpg"
  title: "testing_with_octopus.jpg"
---
While looking for some tooling for testing Kubernetes deployments I've bumped into [octopus](https://github.com/kyma-incubator/octopus) made as a part of Kyma project. It allows running tests in similar manner as helm test but treating test definitions and executions as kubernetes resources. I thought it is perfect tool for running tests that are encapsulated as containers, i.e. rf-service that I'm working on. In this article I'm describing how I made [KubeLibrary](https://github.com/devopsspiral/KubeLibrary), [rf-service](https://github.com/devopsspiral/rf-service/tree/v0.3.1) and octopus work together. 

<div class="panel radius" markdown="1">
**Table of Contents**
{: #toc }
*  TOC
{:toc}
</div>

## Context

This article is a part of series connected with testing on Kubernetes. You can find more info in following articles:

[Robot Framework library for testing Kubernetes](https://devopsspiral.com/articles/k8s/robotframework-kubelibrary/) - in this part I'm describing Robot Framework library (Python) that uses Kubernetes client for getting info about your cluster and turning it into actual test suites.

[Testing on kubernetes - rf-service](https://devopsspiral.com/articles/k8s/robotframework-service/) - this article describes Python service executed in a form of CronJob that actually runs the tests from KubeLibrary on kubernetes cluster.

<small markdown="1">[Back to table of contents](#toc)</small>

## Why octopus is such a good fit?

Testing kubernetes deployments is for sure something that is not that evolved as other parts of kubernetes world. We assume that things defined in YAML files will be delivered as we expect but does it really differ from regular programming? It becomes even more crucial when the final YAML is templated as in helm case. This was noticed by helm team and implemented as [helm test](https://helm.sh/docs/topics/chart_tests/) functionality. The concept of encapsulating all the needed testing tools in container and running them against deployment is neat, the problem is that those tests are not treated as first class kubernetes citizens.

Kyma-project Octopus took steps towards making this happen, you can find whole motivation in their [blog post](https://kyma-project.io/blog/2020/1/16/integration-testing-in-k8s). Basically, they turned 0/1 helm test approach into handling test as actual resource that can be retried, filtered and executed in parallel. It was used in integration testing context, but could be easily used as recurring health checks.

Now you only need container with your test suites to execute on demand, which is exactly what rf-service is supposed to provide. Till now it was triggered as CronJob so there was schedule and possible repeatability, implemented changes allows taking advantage of running it within octopus. You can find more info about what was actually added in below section.

<small markdown="1">[Back to table of contents](#toc)</small>

## Essential changes to rf-service

In this article I'm only focusing on running rf-service as standalone container, but it can be started as REST API based service for running tests on demand. 

### CLI support

Till now rf-service configuration was done by passing .json file with *fetcher* - functionality for collecting tests suites and *publisher* - functionality for publishing robotframework results. This meant that there was a need to make the container read some file or be mounted with it - by attaching ConfigMap for example. Running it using octopus demanded adding possibility to define all configuration using CLI parameters.

To avoid maintaining growing list of hardcoded CLI parameters, they are generated dynamically from metadata of fetcher and publisher classes. Meaning that below CLI execution:

{% highlight bash %}
rf-service --LocalFetcher-src ~/test/source --LocalPublisher-dest ~/test/results
{% endhighlight %}

is equivalent with following json configuration file:

{% highlight json %}
{
    "fetcher": {
        "type": "LocalFetcher",
        "src": "~/test/source"
    },
    "publisher": {
        "type": "LocalPublisher",
        "dest": "~/test/results"
    }
}
{% endhighlight %}

allowing pretty flexible configuration of rf-service.

<small markdown="1">[Back to table of contents](#toc)</small>

### Execution by tag

Tagging tests in Robot Framework is powerful way of handling test execution and in general categorizing testcases. Since rf-service fetches complete test suites, allowing executing only part of them is a must and has been mirrored from Robot Framework CLI. To include tags pass `-i <tag>` to exclude tags use `-e <tag>`. Those values are then passed to Robot Framework so you can expect all the behaviors to be exactly the same.

<small markdown="1">[Back to table of contents](#toc)</small>

### Dependency resolution

In a path towards making rf-service generic enough to be executed as a base for different kinds of testcases, support for pip requirements was added. This way if fetcher collects directory containing *requirements.txt* file, it will install packages as with `pip install -r requirements.txt`. Just remember first spotted requirements.txt file will be used, so it is best to keep one in top level directory.

<small markdown="1">[Back to table of contents](#toc)</small>

## Running tests

Alright let's run some tests then. I will be running testcases from [KubeLibrary/testcases](https://github.com/devopsspiral/KubeLibrary/tree/v0.1.4/testcases) and using KubeLibrary as a testing library itself.

As a first step you need to install octopus from the chart provided in its [repository](https://github.com/kyma-incubator/octopus).

{% highlight bash %}
git clone https://github.com/kyma-incubator/octopus
cd octopus
helm install octopus ./chart/octopus/
{% endhighlight %}

Then, we need to define what and how the tests will be executed. All those things are configured using kubernetes resources (CRD) brought by octopus. In *TestDefinition* you define how the test container is executed in similar way kubernetes deployment is defined. In my case, test definition is defined as follows:

{% highlight yaml %}
# test-definition.yaml
apiVersion: testing.kyma-project.io/v1alpha1
kind: TestDefinition
metadata:
  labels:
    component: kube-tests
  name: test-example
spec:
  template:
    spec:
      serviceAccountName: octopus-sa
      containers:
        - name: test
          image: mwcislo/rf-service:0.3.0
          command:
                  - "rf-service"
                  - "--ZipFetcher-url"
                  - "https://github.com/devopsspiral/KubeLibrary/archive/v0.1.4.zip"
                  - "--ZipFetcher-path"
                  - "KubeLibrary-0.1.4/testcases"
                  - "--LocalPublisher-dest"
                  - "somecontext"
                  - "-i"
                  - "octopus"
          env:
                  - name: KLIB_POD_PATTERN
                    value: octopus.*
                  - name: KLIB_POD_NAMESPACE
                    value: default
                  - name: KLIB_POD_LABELS
                    value: "{\"app\":\"octopus\"}"
                  - name: KLIB_ENV_VARS
                    value: "{\"SECRET_NAME\":\"webhook-server-secret\"}"
                  - name: KLIB_RESOURCE_REQUESTS_CPU
                    value: 100m
                  - name: KLIB_RESOURCE_REQUESTS_MEMORY
                    value: 20Mi
                  - name: KLIB_RESOURCE_LIMITS_CPU
                    value: 100m
                  - name: KLIB_RESOURCE_LIMITS_MEMORY
                    value: 30Mi

{% endhighlight %}

Shortly speaking I'm telling rf-service to take tests from KubeLibrary repository (branch master) on path testcases/ and publish results locally in directory *somecontext* - the actual path doesn't really matter in this case. The execution should only include tests with tag *octopus*. All the environment variables are just parameterized test variables, it is attempt to make the tests more generic and possibly use same tests with different test targets, i.e. different services.

You might noticed `serviceAccountName: octopus-sa` part, this is needed to run the test container in privileged mode so that it can talk to different parts of kubernetes API and depends on what you really need to test. Below I'm showing the resources that needs to be applied to make it cluster-admin privileged.

{% highlight yaml %}
# serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: octopus-sa
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: octopus-admin-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: octopus-sa
  namespace: default
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
{% endhighlight %}

The second part that needs to be applied is *ClusterTestSuite*, which represents how the test should be actually executed. Tests are matched by label, which again allows convenient way of grouping tests. Other parameters are **count** - how many times test should be repeated, **maxRetries** - how many times can be repeated if failed and **concurrency** - how many tests can run in parallel, in our case we only have one test so any changes here takes no effect, but when you are running a lot of tests (TestsDefinitions) it can save a lot of time.

{% highlight yaml %}
# cluster-test-suite.yaml
apiVersion: testing.kyma-project.io/v1alpha1
kind: ClusterTestSuite
metadata:
  labels:
    controller-tools.k8s.io: "1.0"
  name: testsuite-selected-by-labels
spec:
  count: 1
  maxRetries: 1
  concurrency: 1
  selectors:
    matchLabelExpressions:
      - component=kube-tests
{% endhighlight %}

To run the tests just apply all the files using kubectl, starting with serviceaccount.yaml. After couple of seconds you should see new pod being created and inside of it, there will be rf-service running KubeLibrary tests from within the cluster. You should see all the results in container logs, to view them just use regular logs lookup `kubectl logs oct-tp-testsuite-selected-by-labels-test-example-0`:

{% highlight bash %}
(...)
==============================================================================
A6D70814-B63C-49Ba-B82F-8778B7D86De9                                          
==============================================================================
A6D70814-B63C-49Ba-B82F-8778B7D86De9.KubeLibrary-master                       
==============================================================================
A6D70814-B63C-49Ba-B82F-8778B7D86De9.KubeLibrary-master.Testcases             
==============================================================================
A6D70814-B63C-49Ba-B82F-8778B7D86De9.KubeLibrary-master.Testcases.Pod         
==============================================================================
A6D70814-B63C-49Ba-B82F-8778B7D86De9.KubeLibrary-master.Testcases.Pod.Pod     
==============================================================================
Pod images has correct version                                        | PASS |
------------------------------------------------------------------------------
Pod has enough replicas                                               | PASS |
------------------------------------------------------------------------------
Pod has not been restarted                                            | PASS |
------------------------------------------------------------------------------
Pod have correct labels                                               | PASS |
------------------------------------------------------------------------------
Pod has correct limits/requests                                       | PASS |
------------------------------------------------------------------------------
Pod has correct env variables                                         | PASS |
------------------------------------------------------------------------------
A6D70814-B63C-49Ba-B82F-8778B7D86De9.KubeLibrary-master.Testcases.... | PASS |
6 critical tests, 6 passed, 0 failed
6 tests total, 6 passed, 0 failed
==============================================================================
A6D70814-B63C-49Ba-B82F-8778B7D86De9.KubeLibrary-master.Testcases.Pod | PASS |
6 critical tests, 6 passed, 0 failed
6 tests total, 6 passed, 0 failed
==============================================================================
A6D70814-B63C-49Ba-B82F-8778B7D86De9.KubeLibrary-master.Testcases     | PASS |
6 critical tests, 6 passed, 0 failed
6 tests total, 6 passed, 0 failed
==============================================================================
A6D70814-B63C-49Ba-B82F-8778B7D86De9.KubeLibrary-master               | PASS |
6 critical tests, 6 passed, 0 failed
6 tests total, 6 passed, 0 failed
==============================================================================
A6D70814-B63C-49Ba-B82F-8778B7D86De9                                  | PASS |
6 critical tests, 6 passed, 0 failed
6 tests total, 6 passed, 0 failed
==============================================================================
Output:  /output.xml
{% endhighlight %}

Test execution status is kept in ClusterTestSuite resource, you can use it to view resulting status, start time, completion time and others. This allows getting overview of multiple suites execution and keeping its records. 


{% highlight bash %}
$kubectl get ClusterTestSuite
NAME                           AGE
testsuite-selected-by-labels   18s

$kubectl describe ClusterTestSuite testsuite-selected-by-labels
Name:         testsuite-selected-by-labels
Namespace:    
Labels:       controller-tools.k8s.io=1.0
Annotations:  API Version:  testing.kyma-project.io/v1alpha1
Kind:         ClusterTestSuite
Metadata:
  Creation Timestamp:  2020-07-26T13:21:14Z
  Generation:          1
  Resource Version:    684
  Self Link:           /apis/testing.kyma-project.io/v1alpha1/clustertestsuites/testsuite-selected-by-labels
  UID:                 f2f11a7d-8927-47cb-a125-0f107018194c
Spec:
  Concurrency:  1
  Count:        1
  Max Retries:  1
  Selectors:
    Match Label Expressions:
      component=kube-tests
Status:
  Completion Time:  2020-07-26T13:22:16Z
  Conditions:
    Status:  False
    Type:    Running
    Status:  True
    Type:    Succeeded
  Results:
    Executions:
      Completion Time:  2020-07-26T13:22:16Z
      Id:               oct-tp-testsuite-selected-by-labels-test-example-0
      Pod Phase:        Succeeded
      Start Time:       2020-07-26T13:21:15Z
    Name:               test-example
    Namespace:          default
    Status:             Succeeded
  Start Time:           2020-07-26T13:21:14Z
Events:                 <none>
{% endhighlight %}

<small markdown="1">[Back to table of contents](#toc)</small>

## Conclusion

In my opinion octopus is very interesting project and might play important role whenever kubernetes is used, by filling testing gap. As someone said YAML became k8s programming language and as every programming language needs some holistic approach to testing. Observing what octopus can and what are the proposals seen in the project [issues](https://github.com/kyma-incubator/octopus/issues) seems it can be good move towards it.

<small markdown="1">[Back to table of contents](#toc)</small>