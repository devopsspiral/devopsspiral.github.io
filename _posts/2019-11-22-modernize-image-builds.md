---
layout: page
#
# Content
#

title: "Modernizing image builds using BuildKit"
teaser: "In this article I'm showing bunch of BuildKit features that can make your container images builds easier, faster and more secured."
header:
  background-color: "#4472c4"
  image: logo_colors.svg
  title: DevOps Spiral
categories:
  - articles
  - containers
tags:
  - containers
  - kubernetes
  - docker
  - build images
image:
  homepage: "modernize-image-builds.jpg"
  thumb: "modernize-image-builds.jpg"
  header: "modernize-image-builds.jpg"
  title: "modernize-image-builds.jpg"
  caption: 'Image by <a href="https://pixabay.com/users/Engin_Akyurt-3656355/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=2076885">engin akyurt</a> from <a href="https://pixabay.com/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=2076885">Pixabay</a>'
---
Container world is expanding rapidly and so are tools for building container images. There are quite many options available, but BuildKit seems to really target quite many pain points of regular `docker build`. It is project maintained in moby ecosystem and as such is also being integrated with docker engine gradually. With docker engine 19.03 releases (started on July 2019) support for buildx was added. Buildx is CLI plugin for docker that extends its capabilities with additional BuildKit features. I will try to show some practical examples of those.

<div class="panel radius" markdown="1">
**Table of Contents**
{: #toc }
*  TOC
{:toc}
</div>

## Making your builds better as fast as possible

I will assume that you already have docker engine version >19.03, in previous releases some of BuildKit features were already enabled and you could use them with some extra configuration. Starting from 19.03 the only thing that you need to do to really quickly start builds with BuildKit backend is to set following flag.

{% highlight bash %}
export DOCKER_BUILDKIT=1
{% endhighlight %}

It is still in experimental mode so you need to explicitly tell that you want to use it. With this simple change you are already gaining better caching and faster builds. You can do tests on your own to see the difference in build time, if you want to see comparison in numbers see [Building images efficiently and securely on Kubernetes with BuildKit](https://www.slideshare.net/AkihiroSuda/kubeconeu-building-images-efficiently-and-securely-on-kubernetes-with-buildkit) by *Akihiro Suda*, which was my motivation for checking BuildKit in action.

<small markdown="1">[Back to table of contents](#toc)</small>

## Parallel execution

Enabling BuildKit gives you another big advantage - multistage builds are executed in parallel. BuildKit is smart enough to see which stages are independent and can be executed separately. In one of the github issues connected with parallel execution I've found great example of dockerfile that shows BuildKit concurrent builds in action, you can try it out yourself.

{% highlight bash %}
# Image one
FROM alpine as one
RUN mkdir -p /opt/one/
RUN sleep 5

# Image two
FROM alpine as two
RUN mkdir -p /opt/two/
RUN sleep 5

# Image three
FROM alpine as three
RUN mkdir -p /opt/three/
RUN sleep 5

# Image four
FROM alpine as four
RUN mkdir -p /opt/four/
RUN sleep 5

# Image Final
FROM alpine:latest
COPY --from=one /opt/one /opt/one
COPY --from=two /opt/two /opt/two
COPY --from=three /opt/three /opt/three
COPY --from=four /opt/four /opt/four
{% endhighlight %}

<small markdown="1">[Back to table of contents](#toc)</small>

## Builders

BuildKit has also concept of builders, which represents different instances for building specific applications in specific context. It becomes even more compelling knowing that you can have many workers for same builder and build containers for different platforms (*--platform* option). This is functionality that needs buildx in place. You need to download binary from [buildx releases](https://github.com/docker/buildx/releases) and place it as `~/.docker/cli-plugins/docker-buildx`. Remember to make it executable too (`chmod +x ~/.docker/cli-plugins/docker-buildx`). You should now have `docker buildx` management command available. With buildx in place `DOCKER_BUILDKIT` variable is not needed if you will be using `docker buildx build` for building your images.

You can list builders as follows.

{% highlight bash %}
$ docker buildx ls
NAME/NODE     DRIVER/ENDPOINT             STATUS PLATFORMS
default       docker                              
  default     default                     running linux/amd64, linux/386
{% endhighlight %}

As you can see you already have default builder that is delivered with your docker engine. For multi-platform support and cache export you need to have docker-container builder, which is buildkitd daemon running inside docker container. Let's create one now.

{% highlight bash %}
# create builder with name newbuilder
$ docker buildx create --name newbuilder --use

# list builders
$ docker buildx ls
NAME/NODE     DRIVER/ENDPOINT             STATUS   PLATFORMS
newbuilder *  docker-container                     
  newbuilder0 unix:///var/run/docker.sock inactive 
default       docker                               
  default     default                     running  linux/amd64, linux/386

# run some build
$ docker buildx build -t parallel .
WARN[0000] No output specified for docker-container driver. Build result will only remain in the build cache. To push result image into registry use --push or to load image into docker use --load 
[+] Building 51.4s (18/18) FINISHED                                                                              
 => [internal] booting buildkit                                                                            22.8s
 => => pulling image moby/buildkit:buildx-stable-1                                                         20.8s
 => => creating container buildx_buildkit_newbuilder0                                                       2.0s
 => [internal] load .dockerignore                                                                           0.1s
 => => transferring context: 2B                                                                             0.0s
 => [internal] load build definition from Dockerfile                                                        0.1s
 => => transferring dockerfile: 495B                                                                        0.0s
 => [internal] load metadata for docker.io/library/alpine:latest                                           16.7s
 => [stage-4 1/5] FROM docker.io/library/alpine:latest@sha256:c19173c5ada610a5989151111163d28a673683627625  2.5s
 => => resolve docker.io/library/alpine:latest@sha256:c19173c5ada610a5989151111163d28a67368362762534d8a812  0.0s
 => => sha256:c19173c5ada610a5989151111163d28a67368362762534d8a8121ce95cf2bd5a 1.64kB / 1.64kB              0.0s
 => => sha256:e4355b66995c96b4b468159fc5c7e3540fcef961189ca13fee877798649f531a 528B / 528B                  0.0s
 => => sha256:89d9c30c1d48bac627e5c6cb0d1ed1eec28e7dbdfbcc04712e4c79c0f83faf17 2.79MB / 2.79MB              1.8s
 => => sha256:965ea09ff2ebd2b9eeec88cd822ce156f6674c7e99be082c7efac3c62f3ff652 1.51kB / 1.51kB              0.0s
 => => unpacking docker.io/library/alpine:latest@sha256:c19173c5ada610a5989151111163d28a67368362762534d8a8  0.3s
 => [four 1/3] FROM docker.io/library/alpine@sha256:c19173c5ada610a5989151111163d28a67368362762534d8a8121c  0.1s
 => => resolve docker.io/library/alpine@sha256:c19173c5ada610a5989151111163d28a67368362762534d8a8121ce95cf  0.0s
 => [four 2/3] RUN mkdir -p /opt/four/                                                                      0.4s
 => [three 2/3] RUN mkdir -p /opt/three/                                                                    0.4s
 => [one 2/3] RUN mkdir -p /opt/one/                                                                        0.4s
 => [two 2/3] RUN mkdir -p /opt/two/                                                                        0.4s
 => [three 3/3] RUN sleep 5                                                                                 8.4s
 => [two 3/3] RUN sleep 5                                                                                   3.4s
 => [four 3/3] RUN sleep 5                                                                                  5.4s
 => [one 3/3] RUN sleep 5                                                                                   5.4s
 => [stage-4 2/5] COPY --from=one /opt/one /opt/one                                                         0.1s
 => [stage-4 3/5] COPY --from=two /opt/two /opt/two                                                         0.1s
 => [stage-4 4/5] COPY --from=three /opt/three /opt/three                                                   0.1s
 => [stage-4 5/5] COPY --from=four /opt/four /opt/four

{% endhighlight %}

In the last step, actual container will be started - you can see it with `docker ps`. First execution can take some time because builder image is pulled, afterwards you shouldn't see much difference between containerized builder and default one. What is great about it is that now you have independent container that is doing builds for you, also you can now add more workers for same builder and split the work between them (*\-\-node*, *\-\-append*). We will not do that now, instead... we will play with kubernetes.

<small markdown="1">[Back to table of contents](#toc)</small>

## Buildkitd on kubernetes

Yes, the creators of BuildKit where kind enough to make deployment of buildkitd instances on kubernetes really easy. Actually there are many options to do that in [BuildKit repo](https://github.com/moby/buildkit/tree/master/examples/kubernetes). I will use simple deployment with service just to show how this works.

As a first step we need to generate certificates to secure the communication from our machine to remote buildkitd. Just clone [BuildKit repo](https://github.com/moby/buildkit.git), in *examples/kubernetes* there is *create-certs.sh* script with single mkcert dependency, you can find instructions on how to install it [here](https://github.com/FiloSottile/mkcert#installation). Then just run `./create-certs.sh 127.0.0.1`, which will create .certs directory with all needed files. Following instructions from examples/kubernetes execute following lines.

{% highlight bash %}
$ kubectl apply -f .certs/buildkit-daemon-certs.yaml
$ kubectl apply -f deployment+service.rootless.yaml
{% endhighlight %}

So we have remote builder waiting to be used for building images and it is rootless if you didn't notice! You can check k8s deployment to find out that it is using UID 1000, so you just made your CI more secure.

Yet we need another piece to send builds to buildkitd on kubernetes which is *buildctl*. Just download the archive from [BuildKit releases](https://github.com/moby/buildkit/releases) it contains buildctl and buildkitd. If at this point you are already confused with all those executables you are not alone. Those are just different binaries exposing BuildKit functionality. So we have:

| Binary        |  Usage     |
| ------------- | ---------- |
| [buildx](https://github.com/docker/buildx)   | Docker CLI plugin for BuildKit |
| [buildctl](https://github.com/moby/buildkit) | BuildKit CLI |
| [buildkitd](https://github.com/moby/buildkit) | BuildKit daemon for actual building images |
| docker | Since docker engine 19.03 parts of BuildKit are integrated with docker, as mentioned `export DOCKER_BUILDKIT=1` switches to BuildKit backend |

Getting back to our goal of building images on remote kubernetes cluster, running below command will securely send content to remote builder. I'm using port-forward, but you could expose buildkitd as any other service.

{% highlight bash %}
$ kubectl port-forward service/buildkitd 1234 &
$ buildctl --addr tcp://127.0.0.1:1234 --tlscacert .certs/client/ca.pem --tlscert .certs/client/cert.pem --tlskey .certs/client/key.pem build --frontend=dockerfile.v0 --local context=. --local dockerfile=.
{% endhighlight %}

If we take a closer look at the build command we are pointing to remote builder, passing certs, configuring docker context and dockerfile. You might wonder what *\-\-frontend* is? BuildKit allows plugging in different representations of build commands. In this case I used  regular Dockerfile, but there are other options out there:

* [Buildpacks](https://github.com/tonistiigi/buildkit-pack)
* [Mockerfile](https://github.com/r2d4/mockerfile)
* [Gockerfile](https://github.com/po3rin/gockerfile)

<small markdown="1">[Back to table of contents](#toc)</small>

## Remote cache

If we scale up the buildkitd deployment we could distribute the build requests between number of pods. The problem is that those could only count on their local cache. What can be done to fix this is to use cache from remote registry, which would serve as shared source of truth(cache). BuildKit currently doesn't support self-signed certificates for registry (see [this PR](https://github.com/moby/buildkit/pull/677)), so I used docker hub as my remote cache. 

Assuming that my builder has cached my last build, I can now run build again but this time sending output of the build (layers and cache) to docker hub.

{% highlight bash %}
$ buildctl --addr tcp://127.0.0.1:1234 --tlscacert .certs/client/ca.pem --tlscert .certs/client/cert.pem --tlskey .certs/client/key.pem build --frontend=dockerfile.v0 --local context=. --local dockerfile=. --output type=image,name=mwcislo/devopsspiral:parallel,push=true --export-cache type=registry,ref=mwcislo/devopsspiral:cache,mode=max
{% endhighlight %}

I just added parameters for pushing result image to registry and exporting cache. What is important I choose to use *mode=max* which will export all layers from all intermediate steps instead of *mode=min* taking only result image layers. Now to use this option I also have to use *type=registry* in the first place and this means my layers and cache are saved separately, that is why I'm passing two \"places\" in my docker registry.

To prove that remote cache is working I will now prune local cache and add *\-\-import-cache* to use cache from registry. If you are testing it by yourself you should see layers still hitting cache even though layers were not there locally when build started.

{% highlight bash %}
# remove local cache
$ buildctl --addr tcp://127.0.0.1:1234 --tlscacert .certs/client/ca.pem --tlscert .certs/client/cert.pem --tlskey .certs/client/key.pem prune

# notice added --import-cache
$ buildctl --addr tcp://127.0.0.1:1234 --tlscacert .certs/client/ca.pem --tlscert .certs/client/cert.pem --tlskey .certs/client/key.pem build --frontend=dockerfile.v0 --local context=. --local dockerfile=. --output type=image,name=mwcislo/devopsspiral:parallel,push=true --export-cache type=registry,ref=mwcislo/devopsspiral:cache,mode=max --import-cache type=registry,ref=mwcislo/devopsspiral:cache
{% endhighlight %}

<small markdown="1">[Back to table of contents](#toc)</small>

## Wrapping things up

Hope that I convinced you that by sticking to regular *docker build* you are really missing much. If you don't want to change everything at once and you have docker >19.03 just try the `export DOCKER_BUILDKIT=1` and you should already see the difference. I focused only on builder setup but there is much more offered by BuildKit (mounting cache dirs and secrets, platform builds, garbage collection, frontends) - putting all of it in one article would be too much. Hopefully I will find some time to cover the other part too.

<small markdown="1">[Back to table of contents](#toc)</small>
