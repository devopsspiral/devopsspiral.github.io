---
layout: page
#
# Content
#

title: "Testing on kubernetes with KubeLibrary"
teaser: "In this article I'm showing KubeLibrary that was written to enable testing on kubernetes using RobotFramework."
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
  homepage: "rf-kubelibrary.jpg"
  thumb: "rf-kubelibrary.jpg"
  header: "rf-kubelibrary.jpg"
  title: "rf-kubelibrary.jpg"
  caption: 'Image based on work of <a href="https://pixabay.com/users/Republica-24347/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=606612">Republica</a> from <a href="https://pixabay.com/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=606612">Pixabay</a>'
---
I was using Robot Framework for some time already and still think it is one of the best tools for testing. It can be utilized for all kinds of end-to-end tests including acceptance, integration and regression tests. It can also be successfully used in Kubernetes, that is how KubeLibrary originated. In this article I'm showing KubeLibrary that was written to enable testing on kubernetes using Robot Framework.

<div class="panel radius" markdown="1">
**Table of Contents**
{: #toc }
*  TOC
{:toc}
</div>

## Motivation

Although Kubernetes offer declarative deployments and in general we should expect things being applied according to what we define, there still needs to be verification of the definitions itself. Writing complicated deployments including helm charts can be hard and needs testing. Furthermore, how the automation delivers what we defined is another thing to check. This becomes even more necessary if you are developing platform itself, like supporting services for your business logic. In this case those test can be treated as part of TDD or regular tests for whatever you are adding on top of kubernetes.

I also think that running tests periodically in working system has a big value. Logs, traces and metrics are not always enough to quickly investigate the potential problems. With e2e test you can isolate problem, focus on specific functionality and provide context to what you dig deeper afterwards in metrics and logs. This makes testing more like health checks that you can just quickly run to assure your system is providing what you promised.

If you think that creating those tests is just extra effort it doesn't needs to be like that. Whatever is created for your CI pipeline for particular application can be candidate for those tests on cluster level - only if it is high-level enough. In other words you can use same tests on many stages along with assuring that your live environment is ok.

<small markdown="1">[Back to table of contents](#toc)</small>

## Intro to Robot Framework and why you might want to use it

There are couple of things that makes Robot Framework good option for above considerations. First of all, it has its own syntax which is more like natural language rather than programming language which can be found in other testing frameworks. If you would also use given-when-then formula, test procedure becomes readable even for non programmers. Below you can find example from KubeLibrary testcases.

{% highlight bash %}
Pods in kube-system are ok
    [Documentation]  Test if all pods in kube-system initiated correctly and are running or succeeded
    [Tags]    cluster    smoke
    Given kubernetes API responds
    When getting pods in "kube-system"
    Then all pods in "kube-system" are running or succeeded
{% endhighlight %}

Robot Framework is also easily extensible, it already have a lot of libraries covering many fields of testing, but if it is not enough you can always add your own functionality using Python. You can use some basic programming structures (like loops) in test case definition, but this approach quickly mess up you test code. It is best to just keep testcases clean and understandable for everyone and hide implementation details in Python code which is super easy to write.

Lastly, output from each test run is generated in form of HTML file, where you can easily navigate between cases and investigate why test failed. This is actually very important as viewing tests result in plain text quickly becomes unmanageable for multiple tests, while HTML report can be easily embedded on some site or just viewed in browser.

<small markdown="1">[Back to table of contents](#toc)</small>

## KubeLibrary

### Structure

Code of KubeLibrary can be found on [github](https://github.com/devopsspiral/KubeLibrary). KubeLibrary is just usage of official Python Kubernetes client to write some simple functions that gather info from working cluster, which then can be used as part of tests. All the code is in one KubeLibrary.py file. In *testcases* you can find some example tests that uses KubeLibrary. Test building blocks called keywords are kept in *\*_kw.robot* files, those represents high-level functions that can be parameterized. Then in the rest of *.robot* files you can find actual tests written in given-when-then structure.

<small markdown="1">[Back to table of contents](#toc)</small>

### Installation

KubeLibrary is published on PyPI as robotframework-kubelibrary. To be able to run tests you need to install KubeLibrary using pip first. It has Robot Framework as dependency so you should be ready for using `robot` binary without extra steps.

{% highlight bash %}
# KubeLibrary has newer versions, but to match article content from the past use below version
pip install robotframework-kubelibrary==0.1.2
{% endhighlight %}

If you want to run all the tests from */testcases* you also need to install extra dependencies for some of the tests.

{% highlight bash %}
pip install robotframework-requests
{% endhighlight %}

With KUBECONFIG env variable set already you should be able to run all the tests on you cluster. Obviously most of them if not all will fail, because your environment has different configuration than mine. To execute tests just run `robot testcases`. Notice the last lines of RF output, where you can find result HTML files.

{% highlight bash %}
==============================================================================
Output:  /home/wcislo/git/KubeLibrary/output.xml
Log:     /home/wcislo/git/KubeLibrary/log.html
Report:  /home/wcislo/git/KubeLibrary/report.html
{% endhighlight %}

<small markdown="1">[Back to table of contents](#toc)</small>

### Example test

I will not go into too many details about Robot Framework syntax, you can use [Robot Framework User Guide](https://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html) as reference. Just basic walk-through of test case to make you run your first tests.

{% highlight bash %}
Grafana has correct version
    [Documentation]  Test if Grafana container image is in correct version
    [Tags]    grafana
    Given kubernetes API responds
    When accessing "grafana-" excluding "svclb" container images version in "default"
    Then "grafana/grafana:6.5.0" version is used
{% endhighlight %}

Each test in Robot Framework has definition below test name, indented with at least 2 spaces (I'm using 4). As first lines you can define extra parameters like *Documentation* of test case and *Tags*. Tags are very useful because it allows running only tests with specific label. If you would like to run tests only for Grafana you could run it using `robot -i grafana testcases` (*-i* stands for include).

Other lines of test refers to keywords defined in *\*_kw.robot* file. Given, When, Then and And clauses are omitted, so in keyword file you will find keyword with name *kubernetes API responds* if we take a first one as an example. What is really great about RF is that testcases are very readable if you follow certain rules. On top of it you can parameterize keywords by passing arguments as a part of its name. If you notice last keyword from test case and check its definition, first word passed is then used as variable in keyword. As you can see below, in this keyword all pods containers images are checked against passed string ("grafana/grafana:6.5.0").

{% highlight bash %}
"${version}" version is used
    : FOR    ${Item}    IN    @{pods_images}
    \     Should Be Equal As Strings    ${Item}    ${version}
{% endhighlight %}

Given-when-then approach forces to divide the test into stages: Given - check prerequisites, When - gather info, Then - assertion. Very often you need to pass some variables between keywords, especially for When > Then part. Fortunately RF allows exporting variables so that they become accessible in other keywords. Following the same example, you can observe passing of ${pods_images} variable.

{% highlight bash %}
accessing "${pattern}" excluding "${exclude}" container images version in "${namespace}"
    @{pods_images}=    get_pods_images_in_namespace    ${pattern}   ${namespace}    ${exclude}
    Log    ${pods_images}
    Set Test Variable    ${pods_images}

"${version}" version is used
    : FOR    ${Item}    IN    @{pods_images}
    \     Should Be Equal As Strings    ${Item}    ${version}
{% endhighlight %}

<small markdown="1">[Back to table of contents](#toc)</small>

### Testing Grafana

It is hard to test Kubernetes without any workloads, that is why I used Grafana installed from helm chart as a target for my tests. You can install it with following *values.yaml* file using `helm3 install grafana stable/grafana -f values.yaml`.

{% highlight bash %}
service:
  type: LoadBalancer
  port: 3000
persistence:
  enabled: true
  type: pvc
  size: 1Gi
{% endhighlight %}

All the tests tagged as *grafana* can be used to test this particular deployment.

<small markdown="1">[Back to table of contents](#toc)</small>

##  Conclusion

Obviously writing 11 functions talking to Kubernetes API is not enough to perform extensive tests, but it serves as a good starting point. In example testcases I've also showed couple of patterns that can be utilized to extend KubeLibrary. Most additional efforts are matter of figuring out how to get particular Kubernetes API object you need and how to test what is inside of it.

Testing Kubernetes workloads doesn't end at testing K8s API only, any other RF libraries can be used to perform additional tests on application setup and logic. The big missing part is also how to run those tests. You can always run them from your laptop, but running it from cluster itself would be a lot better. Creating testing service might end up as another article here.

<small markdown="1">[Back to table of contents](#toc)</small>
