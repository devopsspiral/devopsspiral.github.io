---
layout: page
#
# Content
#

title: "Setting up local k8s dev environment with k3d and skaffold"
teaser: "In this article I'm describing how to setup decent kubernetes development environment using k3s/k3d and skaffold."
header:
  background-color: "#4472c4"
  image: logo_colors.svg
  title: DevOps Spiral
categories:
  - articles
  - k8s
tags:
  - k3s/k3d
  - kubernetes
  - skaffold
image:
  homepage: "k3d-skaffold.jpg"
  thumb: "k3d-skaffold.jpg"
  header: "k3d-skaffold.jpg"
  title: "k3d-skaffold.jpg"
  caption: 'Image by <a href="https://pixabay.com/users/Pexels-2286921/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=1838986">Pexels</a> from <a href="https://pixabay.com/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=1838986">Pixabay</a>'
---
Rancher labs is hitting the sweet spot for many problems in kubernetes world: Rancher - k8s management, RKE - k8s commissioning, Submariner - inter cluster communication, RIO - MicroPaaS and finally K3s/K3d - lightweight Kubernetes. I was working with Rancher and RKE for some time and decided to give K3s/K3d a try. In September I also participated in meetup where skaffold was showed, which made me try those two in one shot. There is so much to be told about them, but in this article I just wanted to show how to setup those two together which should be great starting point for further exploration.

<div class="panel radius" markdown="1">
**Table of Contents**
{: #toc }
*  TOC
{:toc}
</div>

## K3s/K3d basics

[K3s](https://github.com/rancher/k3s) is single ~40MB binary with fully featured and **certified** kubernetes. No shortcuts, not packing kubernetes into virtual machine running on your laptop, just fully qualified kubernetes. Rancher Labs was able to make the binary so small by removing all legacy, non-default features, cloud and storage providers specifics and others. All of those, to make it fly on edge devices including Raspberry PI or use it as local environment which is exactly what we will explore in this article. Out of the box you are also getting Traefik as ingress controller, so you could expose your apps right away.

Now [K3d](https://github.com/rancher/k3d) is the dockerized version of K3s, wrapping things connected with K3s into single container image. It is worth to mention that K3s uses containerd as container runtime, so if you run K3d in Docker engine, cluster containers will not be visible in there. Instead you might exec into K3d container and from there run containerd CLI (ctr) `docker exec -it <k3d docker id> ctr containers ls` to list containers in containerd. K3s has containerd socket in */run/k3s/containerd/containerd.sock* in k3d container.

<small markdown="1">[Back to table of contents](#toc)</small>

## Skaffold

[Skaffold](https://github.com/GoogleContainerTools/skaffold) is command line tool for continuous building and deployment for k8s applications. You just make changes to your code or dockerfile and it automatically triggers builds (including image build) and apply changes on k8s cluster. This is great for fast prototyping and fixing deployment issues. Obviously you don't need to trigger deployment on every single tiny change in code, skaffold can also be executed on demand.

<small markdown="1">[Back to table of contents](#toc)</small>

## Putting things together

Having both K3s/K3d and skaffold in hands we can setup pretty nice local dev environment without too much hustle. First the boring part, we need to collect some binaries:

{% highlight bash %}
#k3d - download binary from https://github.com/rancher/k3d/releases
sudo wget https://github.com/rancher/k3d/releases/download/v1.3.4/k3d-linux-amd64 -O /usr/local/bin/k3d
sudo chmod +x /usr/local/bin/k3d

#skaffold
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/v1.0.1/skaffold-linux-amd64 && chmod +x skaffold && sudo mv skaffold /usr/local/bin
{% endhighlight %}

The scenario described in this article was based on skaffold [nodejs example](https://github.com/GoogleContainerTools/skaffold/tree/master/examples/nodejs), so it is best to just clone the skaffold repo and jump to the mentioned example directory.

{% highlight bash %}
git clone https://github.com/GoogleContainerTools/skaffold.git
cd skaffold/examples/nodejs
git checkout 04ccb761b8752e42ca133ca95256f24b2ba2445b
{% endhighlight %}

<small markdown="1">[Back to table of contents](#toc)</small>

### skaffold.yaml is your friend

Skaffold.yaml is all you need to configure for automatic builds and deployments. Let's take a look at the file from the skaffold repo.

{% highlight yaml %}
apiVersion: skaffold/v1
kind: Config
build:
  artifacts:
  - image: gcr.io/k8s-skaffold/node-example
    context: backend
    sync:
      manual:
      # Sync all the javascript files that are in the src folder
      # with the container src folder
      - src: 'src/**/*.js'
        dest: .
{% endhighlight %}

Apart from resource kind and api version we can find there build stage definition. This is configuration for build phase actions, in this case it is specific for dockerfile, but skaffold supports other options like maven/gradle or basically anything that can be wrapped into custom script. You can find more information about build options in [builders](https://skaffold.dev/docs/pipeline-stages/builders/) section of the documentation.

In *artifacts* part you define everything needed to make a (dockerfile) build. First there is image name, then context which is root directory for the build (need to contain actual Dockerfile), and finally sync part. This is another nice feature of skaffold - it allows hot swap of the content in running container, this is mostly used for some static files that might be updated without breaking container logic. In our case this is *manual sync*, which means source and destination of those updates needs to be defined explicitly. There is also *infer* mode available, which allows to perform updates more efficient based on what is defined in dockerfile (see [file sync](https://skaffold.dev/docs/pipeline-stages/filesync/)).

At this point our skaffold.yaml is missing some parts. First of all we would like to not only build but also deploy our app in the k8s cluster. This can be configure with following section, telling skaffold to use kubectl manifest located in k8s/deployment.yaml.

{% highlight yaml %}
deploy:
  kubectl:
    manifests:
    - k8s/deployment.yaml
{% endhighlight %}

If you would like to use BuildKit for your builds, which improves the caching and speed of the builds you can also force skaffold to use it. Just add following key in build section.

{% highlight yaml %}
  local:
    useBuildkit: true
{% endhighlight %}

Last thing is that we are using remote registry here, this is not the best option for local environment where the speed is the most important part and we don't want to wait for image transfers towards distant endpoint. Local docker registry seems a good solution here, so I'll use it here, just change the image name accordingly.

{% highlight yaml %}
  artifacts:
  - image: registry.local:5000/node-example
{% endhighlight %}

After the changes skaffold.yaml should look like below.

{% highlight yaml %}
apiVersion: skaffold/v1
kind: Config
build:
  artifacts:
  - image: registry.local:5000/node-example
    context: backend
    sync:
      manual:
      # Sync all the javascript files that are in the src folder
      # with the container src folder
      - src: 'src/**/*.js'
        dest: .
  local:
    useBuildkit: true
deploy:
  kubectl:
    manifests:
    - k8s/deployment.yaml
{% endhighlight %}

<small markdown="1">[Back to table of contents](#toc)</small>

### Setting up local registry

We just configured skaffold to use local registry, but we don't have registry in place. Let's quickly setup one.

{% highlight bash %}
docker volume create local_registry
docker container run -d --name registry.local -v local_registry:/var/lib/registry --restart always -p 5000:5000 registry:2
{% endhighlight %}

You still need to adjust **k8s/deployment.yaml** in nodejs example to use local registry as image source, updated line should look like below.

{% highlight bash %}
      containers:
      - name: node
        image: registry.local:5000/node-example
{% endhighlight %}

<small markdown="1">[Back to table of contents](#toc)</small>

### Small but mine

We can finally start our own kubernetes cluster and make skaffold deploy nodejs app there using local registry. If you just want a k8s cluster with one worker ASAP run.

{% highlight bash %}
k3d create --workers 1
#to get kubeconfig file
cp "$(k3d get-kubeconfig --name='k3s-default')" ~/.kube/config
{% endhighlight %}

{% include alert text='I noticed `k3d get-kubeconfig --name=k3s-default` might need some time to succeed. So you might need to retry it in case of errors.' %}

To make k3s see our local registry we need some additional steps described in [k3d docs](https://github.com/rancher/k3d/blob/master/docs/examples.md#connect-with-a-local-insecure-registry). You can first delete the cluster if you already started one with `k3d delete`. We can skip the first step of instructions because we already have registry in place. In step 2 we need to create registries.yaml and place it in `/home/${USER}/.k3d`, the content is as follows.

{% highlight bash %}
mirrors:
  "registry.local:5000":
    endpoint:
    - http://registry.local:5000
{% endhighlight %}

Then you can start the cluster with the created file mounted using:

{% highlight bash %}
k3d create --workers 1 --volume /home/${USER}/.k3d/registries.yaml:/etc/rancher/k3s/registries.yaml
cp "$(k3d get-kubeconfig --name='k3s-default')" ~/.kube/config
{% endhighlight %}

There is very important final part, first run `docker network connect k3d-k3s-default registry.local` to put registry inside same network as k3d and then add `127.0.0.1 registry.local` to your /etc/hosts. Remember about second one, I lost some time trying to figure out why things are not working because of this.

Now everything should be ready to actually run `skaffold dev` which will build the container, push it into local registry and finally deploy on k3s kubernetes. After a while you should be able to see you app up and running and exposed. To access it over browser just get the service ip using below command.

{% highlight bash %}
$ kubectl get svc
NAME         TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
kubernetes   ClusterIP      10.43.0.1      <none>        443/TCP          7m2s
node         LoadBalancer   10.43.24.215   172.19.0.3    3000:30371/TCP   4m36s
{% endhighlight %}

In this case you can access your app by heading to http://172.19.0.3:3000, if everything is fine you should see *Hello World!*. You can now try to do some changes to the nodejs project, by for example changing *backend/src/index.js* to something similar to below.

{% highlight js %}
const express = require('express')
const { echo } = require('./utils');
const app = express()
const port = 3000

app.get('/', (req, res) => res.send(echo('Hello World (devopsspiral.com)!')))

app.listen(port, () => console.log(`Example app listening on port ${port}!`))
{% endhighlight %}

You would see skaffold taking actions on this change without image rebuild. Using File sync functionality the file will be changed in container file system directly. Just refresh the browser and you should see updated *Hello World (devopsspiral.com)!* in no time. If you would like to trigger container image build just add `ENV test=1` variable definition at the end of *backend/Dockerfile* and skaffold will do image rebuild too. This is very basic examples but already show the power of this setup.

<small markdown="1">[Back to table of contents](#toc)</small>

## Running the setup behind corporate proxy

Just two things that you need to remember when trying those things behind corporate proxy. First you need to remember to have correct NO_PROXY setting in docker engine to push images to registry.local. In my case I have following line in my */lib/systemd/system/docker.service*.

{% highlight bash %}
Environment="HTTP_PROXY=http://X.X.X.X:Y/" "HTTPS_PROXY=http://X.X.X.X:Y/" "NO_PROXY=localhost,127.0.0.1,registry.local"
{% endhighlight %}

Secondly, you need to actually inform containerd client, in this case k3s, to also use proxy for downloading images. This can be done by passing extra env variable to k3d like so `k3d create --workers 1 ... --env https_proxy=http://X.X.X.X:Y/`

<small markdown="1">[Back to table of contents](#toc)</small>

## Day to day work

We did couple of steps to make things work, after you done all of this it should be much easier the next time you start the environment. Below you can find setup and teardown script that can be used to start/stop the local env with one command.

{% highlight bash %}
#setup.sh
#!/usr/bin/env bash
docker start registry.local
k3d create --workers 1 --volume /home/${USER}/.k3d/registries.yaml:/etc/rancher/k3s/registries.yaml
until $(mv "$(k3d get-kubeconfig --name='k3s-default' 2> /dev/null )" ~/.kube/config > /dev/null 2>&1); do sleep 1; done
{% endhighlight %}

{% highlight bash %}
#teardown.sh
#!/usr/bin/env bash
k3d delete
docker stop registry.local
{% endhighlight %}

<small markdown="1">[Back to table of contents](#toc)</small>

## Summary

Both skaffold and k3s/k3d are great tools that can be used for local development, but there are so many more cases that they can be used including CI, gitops, edge clusters. It can be also discussed if developers really need instant deployment onto kubernetes cluster during whole development life cycle - probably not, at least until app logic is mature enough. Moving towards delivery, maintenance or configuration changes ability to see you app working on live cluster with one command locally cannot be underestimated.

<small markdown="1">[Back to table of contents](#toc)</small>

