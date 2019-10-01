---
layout: page
#
# Content
#

title: "Quick hints on starting with k8s effectively"
teaser: "Basic hints on k8s tooling that should help you when starting journey with kubernetes. Easy to understand and ready to be applied right away to boost basic activities on your cluster."
header:
  background-color: "#4472c4"
  image: logo.png
  title: DevOps Spiral
categories:
  - articles
  - k8s
tags:
  - k8s
  - kubectl
  - helm
  - stern
image:
  homepage: "quick-basic-tooling-setup-k8s.jpg"
  thumb: "quick-basic-tooling-setup-k8s.jpg"
  header: "quick-basic-tooling-setup-k8s.jpg"
  title: "quick-basic-tooling-setup-k8s.jpg"
  caption: 'Image by <a href="https://pixabay.com/users/Free-Photos-242387/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=1209764">Free-Photos</a> from <a href="https://pixabay.com/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=1209764">Pixabay</a>'
---
I tried to gather some of the easy to apply tips connected with kubernetes tooling. Nothing too complicated, so that you wouldn't need to spend much time on understanding how to use it or how it actually works. The idea is to provide no-brainer tricks that can be used right away. For more advanced tools you will probably find your own favourites soon.

<div class="panel radius" markdown="1">
**Table of Contents**
{: #toc }
*  TOC
{:toc}
</div>

## kubectl aliases

You can go really wild with aliases and shortening most used commands. Some ideas can be found in [kubectl-aliases](https://github.com/ahmetb/kubectl-aliases/blob/master/.kubectl_aliases). I will stick to the ones I'm using the most, for more complicated commands you can always use completion (see [kubectl completion](#kubectl-completion)). Just place below code in your *~/.bashrc* file.

{% highlight bash %}
#~/.bashrc
alias k="kubectl"
alias ka="kubectl apply --recursive -f"
alias kd="kubectl delete --recursive -f"
alias kg="kubectl get --recursive -f"
alias kpw="kubectl get pods -w"
{% endhighlight %}

First one is self-explanatory, next 3 are CRUD type operations on file but it also works on directories. If it is something small I want to deploy I go with file, if it is more complicated I put all the YAMLs in directory, which also force me to keep things organized. Last one is just a check on pod status to see how deplyment is going just after I applied it on cluster. Note the *\-\-recursive* flag which will go down pointed directories to apply/delete/get everything.

If you deploy things this way, you can then very easily review what was created with *kg*:

{% highlight bash %}
#$ka nginx
deployment.apps/nginx created
ingress.extensions/nginx created
service/testing-templating created
#$kg nginx
NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx   1/1     1            1           4h4m

NAME                                    HOSTS                                                        ADDRESS                                                                           PORTS   AGE
ingress.extensions/nginx   nginx.my.cluster.net   10.164.196.236,10.164.202.234,10.164.203.0,192.168.0.17,192.168.0.8,192.168.0.9   80      4h4m

NAME                         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
service/nginx   ClusterIP   10.43.214.1   <none>        80/TCP    4h4m
{% endhighlight %}

Names in *kg* output can also be used for further actions (like *kubectl edit*, *kubectl get*, etc.), which is very convenient.

{% highlight bash %}
#$k get ingress.extensions/nginx -o yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
  creationTimestamp: "2019-10-01T10:03:56Z"
  generation: 1
  name: nginx
  namespace: default
  resourceVersion: "356615"
  selfLink: /apis/extensions/v1beta1/namespaces/default/ingresses/nginx
  uid: c801431c-e432-11e9-94ab-fa163eb4bfb5
spec:
  rules:
  - host: nginx.my.cluster.net
    http:
      paths:
      - backend:
          serviceName: nginx
          servicePort: http
        path: /
status:
  loadBalancer:
    ingress:
    - ip: 10.164.196.236
    - ip: 10.164.202.234
    - ip: 10.164.203.0
    - ip: 192.168.0.17
    - ip: 192.168.0.8
    - ip: 192.168.0.9
{% endhighlight %}

<small markdown="1">[Back to table of contents](#toc)</small>

## kubectl completion

The problem I see with defining too many aliases is that they are hard to remember. Fortunately kubectl provides tab completion for both bash and zsh, which can work similar to aliases - you just pass first letters of commands and get suggestions after hitting *TAB*. Again, you need to put following line into your *~/.bashrc* file.

{% highlight bash %}
#~/.bashrc
source <(kubectl completion bash | sed 's/kubectl/k/g')
{% endhighlight %}

As you might noticed I used *sed* to allow completion for our *k* alias that was just created. Unfortunately, it will not work for other aliases without further tricks, but it is totally fine because aliases should cover most frequent commands at this point and others can be quickly constructed with completion.

<small markdown="1">[Back to table of contents](#toc)</small>

## kubectl explain

You would probably use some templates for creating k8s resources which I will try to cover in [Templating with helm](#templating-with-helm), but not that rare you also need to edit or add some parameters to your YAMLs by hand. You can get some assistance with *kubectl explain* command, which shows kubernetes API paramters in manual-style manner. You can find some of the examples below.

{% highlight bash %}
k explain deployment.spec.template | less

# view tree structure
k explain deployment.spec.template --recursive | less

# view complete list of supported resources
k api-resources | less

# different explanation for particular version
k explain deployment.spec.template --api-version='extensions/v1beta1' | less

{% endhighlight %}

Tree structure turns out to be very handy especially when fields like *metadata* occures on many levels and it is easy to place it wrongly. Complete list of supported resources will provide shortnames and API group for each resource, so that you can start digging the parameters in kubernetes documentation, project issues or release updates.

<small markdown="1">[Back to table of contents](#toc)</small>

## Changing kubernetes cluster context

Sooner or later you will face situation where number of kubeconfigs, namespaces and context in general will grow. To make things easier you need to find a way for switching between them efficiently. Very often kubectx and kubens seems to be good option, those are basically bash scripts that allows listing and selecting kubeconfig context and namespace respectively. The problem with those tools is that they are applying changes to kubeconfig files directly. While changing namespace seems to be pretty safe knowing that in most cases namespace represents context of some particular application or workspace, so performing some action on one namespace will probably have no sense on other. With context, things become a bit more tricky, you would often have similar applications in same parts of different clusters. Now, taking into consideration that you can use same kubeconfig in different scripts or even terminals I would prefer to do it differently.

To allow using cluster context per runtime, it would be the best to utilize *KUBECONFIG* env variable that is already used by almost all kubernetes tools and libraries. This way it can be set per terminal and it should not interfere with other processes. This approach forces to use kubeconfig per context or even namespace. Having kubconfig per each context-namespace variation would be painfull, so I think reasonable compromise is to have kubeconfig per context and change namespaces with kubens. To avoid your scripts being switched into other namespace you can always create specific kubeconfig for this particular automation case and use it only within one script.

Even when limiting number of kubeconfig files available, writing their names and exporting *KUBECONFIG* is not very convenient. That is why you can use following entry in *~/.bashrc* file to wrap it in handy *kl* function, "l" goes for load. First of all it will set *KUBECONFIG* env variable for you, assuming that you keep your kubeconfigs in *~/.kube/* directory. Secondly, it has builtin completion for names there, so selecting correct config is just a metter of consistent naming and few *[TAB]* hits. Lastly it will set kubernetes style prompt (kube_ps1) so that you know that you are ready to work with particular cluster/context and namespace. You don't like to have it always on due to other custom prompts you might be using like *git* for example.

{% highlight bash %}
#~/.bashrc

cluster_name()
{
if [[ ! -z "${KUBECONFIG}" ]]; then
        echo $(basename $KUBECONFIG)
else
        echo 'N/A'
fi
}

kl()
{
export KUBECONFIG=~/.kube/$1
export KUBE_PS1_CLUSTER_FUNCTION='cluster_name'
. ~/.kube-ps1.sh
PS1='[\u@\h \W $(kube_ps1)]\$ '
}

_kl_completions()
{
        local cur

        COMPREPLY=()
        cur=${COMP_WORDS[COMP_CWORD]}
        COMPREPLY=($( compgen -W "$(for x in ~/.kube/*; do echo $(basename ${x%}); done)" -- $cur ) )
}

complete -F _kl_completions kl
{% endhighlight %}

Going though the code snippet, first function (*cluster_name*) is supposed to generate cluster context name, so that it can be viewed in prompt. Thanks to kube-ps1 we can define how first part of the prompt will be generated using *KUBE_PS1_CLUSTER_FUNCTION*. Then *kl* function is executing the main part by setting *KUBECONFIG* env variable and configuring kube-ps1. Just remember to copy kube-ps1.sh script from [kube-ps1](https://github.com/jonmosco/kube-ps1) to *~/.kube-ps1.sh*. Last part (*_kl_completions*) provide bash completion for the kubeconfig files, so they can be quickly selected.

As I mentioned already, for switching between namespaces you can use kubens that can be donwloaded from [kubens raw](https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens). To follow naming convention, you can save it as /usr/local/bin/kns.

<small markdown="1">[Back to table of contents](#toc)</small>

## Templating with helm

Helm is package manager used for delivering different kind of applications in kubernetes world. The binaries can be found in [helm releases](https://github.com/helm/helm/releases). In this article I just wanted to point out how it can be used for creating deployment boilerplates whenever you want to play a little bit with application that you just found. It can be just docker image without helm chart or maybe it is missing some resources that are needed for your environment. I find it very useful when working with ingress for example, as this resource only needs changes in service that it is pointing too, having the domain pattern already fixed, it can be easily templated.

Below you can find files that I use when trying out new things, which saves me from editing YAMLs by hand. I got them by creating example helm chart with *helm create tmplt*, which creates working chart for nginx, and then just removed extra parts of it to make it bare simple. I also added two extra parameters so I can easily configure them (containerPort and clusterDN) . I keep the generate folder in *tmplt* in my home dir.

{% highlight bash %}
{% raw %}
# tmplt/templates/deployment.yaml
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  name: {{ include "tmplt.fullname" . }}
  labels:
    app.kubernetes.io/name: {{ include "tmplt.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "tmplt.name" . }}
      app.kubernetes.io/instance: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ include "tmplt.name" . }}
        app.kubernetes.io/instance: {{ .Release.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.containerPort }}
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /
              port: http
          readinessProbe:
            httpGet:
              path: /
              port: http
          resources:
{{ toYaml .Values.resources | indent 12 }}
    {{- with .Values.nodeSelector }}
      nodeSelector:
{{ toYaml . | indent 8 }}
    {{- end }}
    {{- with .Values.affinity }}
      affinity:
{{ toYaml . | indent 8 }}
    {{- end }}
    {{- with .Values.tolerations }}
      tolerations:
{{ toYaml . | indent 8 }}
    {{- end }}
{% endraw %}
{% endhighlight %}


{% highlight bash %}
{% raw %}
# tmplt/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "tmplt.fullname" . }}
  labels:
    app.kubernetes.io/name: {{ include "tmplt.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: {{ include "tmplt.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
{% endraw %}
{% endhighlight %}

{% highlight bash %}
{% raw %}
# tmplt/templates/ingress.yaml
{{- $fullName := include "tmplt.fullname" . -}}
{{- $ingressPath := .Values.ingress.path -}}
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: {{ $fullName }}
  labels:
    app.kubernetes.io/name: {{ include "tmplt.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
{{- with .Values.ingress.annotations }}
  annotations:
{{ toYaml . | indent 4 }}
{{- end }}
spec:
  tls:
    - hosts:
      - "{{ .Release.Name }}.{{ .Values.clusterDN  }}"
      secretName: tls
  rules:
    - host: "{{ .Release.Name }}.{{ .Values.clusterDN  }}"
      http:
        paths:
          - path: {{ $ingressPath }}
            backend:
              serviceName: {{ $fullName }}
              servicePort: http
{% endraw %}
{% endhighlight %}

To make templating easy to use, I also defined another function in my *.bashrc* file. Output from templating is saved in */tmp/* directory not to clutter my filesystem. As first step we need to create directory there. Then, actual templating is done, assuming my helm template/chart is in *~/tmplt* directory and I keep my values files in *~/temp*. Notice the *\-\-notes* flag, it tells helm to also template *NOTES.txt* file, which can be used to persist some of the parameters created during templating (e.g. passwords).

{% highlight bash %}
kt()
{
mkdir /tmp/$1
helm template ~/tmplt -n $1 --notes -f ~/temp/$1.yml --output-dir /tmp/$1
}
{% endhighlight %}

Before I can start templating resources I need to first create config file that will be passed into helm. Taking echo-header application as an example, values file could look like below.

{% highlight yaml %}
# ~/temp/echo.yml
image:
  repository: brndnmtthws/nginx-echo-headers
  tag: latest
ingress:
  path: /
containerPort: 8080
clusterDN: mycluster.net
{% endhighlight %}

The flow of commands can be found below. It should result in working deployment exposed at *https://echo.mycluster.net*.

{% highlight bash %}
#$ kt echo
wrote /tmp/echo/tmplt/templates/service.yaml
wrote /tmp/echo/tmplt/templates/deployment.yaml
wrote /tmp/echo/tmplt/templates/ingress.yaml
wrote /tmp/echo/tmplt/templates/NOTES.txt
#$ ka /tmp/echo/
deployment.apps/echo-tmplt created
ingress.extensions/echo-tmplt created
service/echo-tmplt created
{% endhighlight %}

In this scenario I just deployed application and I could easily do it using helm, but such templating can work also for partial deployments like mentioned ingress, config maps or secrets. And big adventage of it is to keep key parameters in few lines in config file, so they can be easily reviewed. On the other hand, generated files can be easily twicked and reapplied for debugging purposes.

<small markdown="1">[Back to table of contents](#toc)</small>

## stern
To effectively tail logs from multiple pods I'm using stern. Check out [stern releases](https://github.com/wercker/stern/releases) to get the binary for your system. Stern is doing couple of useful things, like timestamping, colouring pod instance and it supports regex too. In most cases seeing logs from deployed containers would boil down to
{% highlight bash %}
#$ stern <name_of_container>*
{% endhighlight %}

But it provides a lot more than that, including viewing logs since timestamp, excluding containers or regex filtering actual log lines. Definitely worth checking out.

<small markdown="1">[Back to table of contents](#toc)</small>