---
layout: page
#
# Content
#

title: "Intro to Vue.js. Testing on kubernetes - rf-service frontend."
teaser: "In this article I'm showing my first steps in Vue.js by adding simple frontend to the existing rf-service."
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
  - Vue.js

image:
  homepage: "robotframework-service-fe.jpg"
  thumb: "robotframework-service-fe.jpg"
  header: "robotframework-service-fe.jpg"
  title: "robotframework-service-fe.jpg"
  caption: 'Image based on <a href="https://pixabay.com/users/GraphicMama-team-2641041/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=1460898">GraphicMama-team</a> from <a href="https://pixabay.com/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=1460898">Pixabay</a>'
---
Vue.js is getting more and more popularity, it is still behind React.js and Angular but catching up. It is known for its clarity and flexibility, that is why it makes a perfect opportunity to learn for frontend noobs such as myself.

<div class="panel radius" markdown="1">
**Table of Contents**
{: #toc }
*  TOC
{:toc}
</div>

## Context

This article is a part of series connected with testing on Kubernetes. It is not mandatory to go through previous articles, but it gives a better understanding of what I'm actually trying to achieve here. The Vue.js intro part is written independently so that with below short description of each of the previous parts you should be fine with going through it.

[Robot Framework library for testing Kubernetes](https://devopsspiral.com/articles/k8s/robotframework-kubelibrary/) - in this part I'm describing Robot Framework library (Python) that uses Kubernetes client for getting info about your cluster and turning it into actual test suites.

[Testing on kubernetes - rf-service](https://devopsspiral.com/articles/k8s/robotframework-service/) - this article describes Python service executed in a form of CronJob that actually runs the tests from KubeLibrary on kubernetes cluster.

The article your reading is a next step, where rf-service gets api and frontend so that tests can be executed on demand and results can be viewed in single web UI.


<small markdown="1">[Back to table of contents](#toc)</small>

## Why Vue.js ?

Instead of repeating same story of what Vue.js is, I would rather focus why it seemed perfect for me - knowing only basics of HTML, js and CSS. Vue.js is said to leverage best parts from React and Angular, making it also more lightweight and easy to learn. This was most important for me so that I can learn quickly and also not spend time on something that is far from the main players. You can find more detailed comparison created by Vue.js core team - [Comparison with Other Frameworks](https://vuejs.org/v2/guide/comparison.html).

Vue.js is also in upward trend which makes it perfect competence investment. On top of that you can expect many other people facing similar problems while learning it so access to information and learning should not be a problem. More on that in [Why Is Vue.js a Front-end Trend of 2020?](https://medium.com/@inverita/why-is-vue-js-a-front-end-trend-of-2020-4081e8c799aa).

The third point that really caught my attention is that you can write mobile apps using Vue Native. I didn't tried it yet, but possibility to implement some cool projects on your mobile sounds very tempting.

<small markdown="1">[Back to table of contents](#toc)</small>

### Installation and first project
The recommended method for installation is through *npm*. If you don't have it yet, this is the prerequisite for further steps. You can install Vue with below command:

{% highlight bash %}
npm install vue
{% endhighlight %}

Installing vue-cli makes a lot of things easier, so I used it also. You can add it with:

{% highlight bash %}
npm install -g @vue/cli
{% endhighlight %}

You can create your first project by executing:
{% highlight bash %}
vue create <project-name>
{% endhighlight %}

This will create everything you need to see Vue.js in action including structure and example project that can be base for you changes as in my case. To see the UI just go to project folder and start the development server with:

{% highlight bash %}
npm run serve
{% endhighlight %}

You should see Hello world app on *http://localhost:8080/*.

<small markdown="1">[Back to table of contents](#toc)</small>

### Components

Simplifying things a lot we can say that Vue.js is templating HTMLs documents using JavaScript. Because this is exactly what browser engines works on and understands. Having HTML document, browser can build DOM (Document Object Model) which is the logical representation of HTML text and this is what is then rendered in front of user's eyes. Modern frameworks uses Virtual DOM which is the higher level abstraction that allows more efficient and manageable way of providing content representation.

<small markdown="1">[Back to table of contents](#toc)</small>

#### Rendering

Knowing above let's just track how actually Vue.js code is being placed in final HTML document. Before that, we can already switch to the actual code of rf-service frontend. Just clone the repo from [devopsspiral/rf-service-fe](https://github.com/devopsspiral/rf-service-fe). Again it is vue project created with vue cli.

We will follow top-down path. If you go to *public/index.html*, you will see how the Vue.js app is mounted.

{% highlight html %}
# public/index.html
<div id="app"></div>
{% endhighlight %}

This is the place where *src/App.vue* is referenced. In App.vue there is *template* and *style* part, so you just literally create parts of your app as self-contained source of HTML and CSS. This looks really simple and is easy to manage. 

{% include alert text='Creating .vue files with template, style and js code is not the only way for templating used in Vue. At some point you can find that it is not enough for all the cases, you can find more info [here](https://vuejsdevelopers.com/2017/03/24/vue-js-component-templates/). ' %}

{% highlight html %}
# src/App.vue
<template>
  <div id="app">
    <div id="nav">
      <router-link to="/">Runner</router-link> |
      <router-link to="/results">Results</router-link>  |
      <router-link to="/config">Configure</router-link>
    </div>
    <router-view/>
  </div>
</template>
{% endhighlight %}

I will explain routers later on, for now we can just assume that *\<router-link\>* is just a link to other parts of our application. Those can be found in *src/views* and *src/components*. There is not much difference of how you create views and components, they are kept separate just for clarity. They serve different functions though. Views are used to present parts of your app to the user, while components could be some internal machinery of your app referenced in views.

In my case Runner.vue, Result.vue and Config.vue are kept as views in *src/views* directory. If you look inside those files, you will see that apart from template and style, we have now extra vue/js logic that makes the whole thing dynamic.

<small markdown="1">[Back to table of contents](#toc)</small>

#### Runner.vue and recursive components

I will just focus on Runner.vue as other views are pretty similar. The template part is simple, we have two components: button and test-list. The first one is just regular HTML button but with vue attribute *v-on:click*, that is pointing into function in *script* part in *method* section. This is how you define action from JS to be linked with HTML object. Just to better understand what is done there I'm performing a POST http call to rf-service api using Axios.

{% highlight html %}
# src/views/Runner.vue
<template>
<div>
    <button v-on:click="runTests">Run All</button>
    <div id="tests"><test-list :children="tests" :indentation="0"></test-list></div>
    
</div> 
</template>
{% endhighlight %}

The second object in template is test-list which is as component in *src/components/TestList.vue*. As you can see Vue components are not only modules in Vue.js code, they become actual HTML tags that can be used in templates. Test-list is a bit more interesting because it implements test tree structure using recursion. If you look into its definition it uses recursive call in template section.

{% highlight html %}
# src/components/TestList.vue
<template>
<div>
      <div :style="indent" @click="toggleChildren">{{ name }}</div>
      <div v-if="showChildren">
      <!-- Recursive call -->
      <test-list
        v-for="child in children"
        :children="child.children"
        :name="child.name"
        :key="child.name"
        :indentation="indentation + 1"
        >
      </test-list>
    </div>
</div> 
</template>
{% endhighlight %}

Other than that, there is `@click` which is shorthand for `v-on:click` and `:style` which is shorthand for `v-bind:style` - this is probably the most used vue directive. It binds the value of the parameter with variable or function in JS and this is where whole reactive magic happens. You don't need to care about updating anything, whatever changes in JS is reflected in HTML.

You can also find *v-if* and *v-for* directives that basically works similar to what can be found in other templating engines (like jinja) and represents conditional rendering and loops. In this case v-if will conditionally render \<div\>, which is by the way boundary of v-if - you don't use anything similar to *endif* for example. On the other side v-for will multiply test-list tags for each child in children.

{% highlight html %}
# src/components/TestList.vue
<script>
  export default {
    name: 'test-list',
    props: ['name', 'children', 'indentation'],
    data() {
      return {
        tests: {},
        showChildren: true
      };
    },
    computed: {
      indent() {
        return { transform: `translate(${this.indentation * 50}px)`}
      }
    },
    methods: {
    toggleChildren() {
      this.showChildren = !this.showChildren;
    },
  }
  }
</script>
{% endhighlight %}

Going to the script section, there are couple of distinct parts there. *name* and *props* is defining test-list representation as (HTML) component with parameters. `data()` is the place for all variables available across whole file. Just remember to add `this.` if you are referencing this variable inside script section. And lastly, we have *computed* and *methods* section. You may wander what is the difference if all in all they are both functions. The difference is in how they are used. `indent()` is actually used as value not action as in `toggleChildren()` case. This is why Vue needs to take some extra care of this value in a sense of reactivity i.e. compute the new value whenever `this.indentation` changes.

In Runner.vue there is another interesting section called *created* which is executed on page loading. In this case, it is another call to api to fetch some parameters metadata.

<small markdown="1">[Back to table of contents](#toc)</small>

### Routing
We did a little round tour of Vue elements and we're back to the point where we would like to put things together. This is where routers come into play. As in other programming languages routers directs the flow into classes or methods, in Vue.js those will be components. If you have your app already created without router, don't worry you can always add it using vue cli.

{% highlight bash %}
vue add router
{% endhighlight %}

This will create necessary files in your project and you will be ready to use it. The actual routing paths are kept in *src/router/index.js* in routes variable. This is where you link paths with components.

{% highlight js %}
# src/router/index.js
const routes = [
  {
    path: '/',
    name: 'Runner',
    component: Runner
  },
  {
    path: '/config',
    name: 'Config',
    component: Config
  },
  {
    path: '/results',
    name: 'Results',
    component: Results
  },
]
{% endhighlight %}

Having the paths you can now link to them as it was done in App.vue.

{% highlight html %}
# src/App.vue
      <router-link to="/">Runner</router-link> |
      <router-link to="/results">Results</router-link>  |
      <router-link to="/config">Configure</router-link>
{% endhighlight %}

<small markdown="1">[Back to table of contents](#toc)</small>

### Dockerizing
All right, we have our app running well in development, what if we would like to actually share it with others as a dockerized service? This couldn't be simpler, just use Dockerfile in the repo (taken from [https://vuejs.org/v2/cookbook/dockerize-vuejs-app.html](https://vuejs.org/v2/cookbook/dockerize-vuejs-app.html)). It doesn't have any app specific parts so it can be used as a base for whatever app you are building.

{% highlight bash %}
# Dockerfile
FROM node:lts-alpine

# install simple http server for serving static content
RUN npm install -g http-server

# make the 'app' folder the current working directory
WORKDIR /app

# copy both 'package.json' and 'package-lock.json' (if available)
COPY package*.json ./

# install project dependencies
RUN npm install

# copy project files and folders to the current working directory (i.e. 'app' folder)
COPY . .

# build app for production with minification
RUN npm run build

EXPOSE 8080
CMD [ "http-server", "dist" ]
{% endhighlight %}

<small markdown="1">[Back to table of contents](#toc)</small>

## Changes in rf-service

Getting back to broader context of this article, [rf-service](https://github.com/devopsspiral/rf-service) got api and frontend. It is still possible to run tests from cron job, but the results can be viewed in Results tab in rf-service-fe. Switch between modes is done by passing `.Values.config` helm parameter with configuration of fetcher and publisher as before. By default it is defined as empty string and all the configuration is done using Vue.js frontend.

As a result we have now 3 containers running: frontend with Vue.js app, rf-service and its api and Caddy serving as a store for Robot Framework results.

<small markdown="1">[Back to table of contents](#toc)</small>

### API

rf-service has now api with following endpoints

| Path           | Method        | Description        |
| -------------- |---------------|--------------------|
| /api/publishers| GET           | list of available Publishers |
| /api/publishers_conf | POST, GET | configure Publisher |
| /api/fetchers  | GET           | list of available Fetchers |
| /api/fetchers_conf | POST, GET | configure Fetcher |
| /api/tests     | GET           | view loaded tests   |
| /api/run       | POST          | run all the tests   |

All the paths have explicit /api/ prefix for simplicity, this could be replaced by Flask blueprints or simply by mounting the app on specific path. Api is also missing swagger docs, which might be covered in future.

The app in final container is served by gevent which allowed to expose api without extra non-python dependencies and allowed easy implementation of backward compatibility.

<small markdown="1">[Back to table of contents](#toc)</small>

### Changes in helm

As a result of having 3 containers in place. I decided to put them into one pod, this resulted in multiple ports in one service

{% highlight yaml %}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "rf-service.fullname" . }}-rf-service
  labels:
    {{- include "rf-service.labels" . | nindent 4 }}
spec:
  type: {{ .Values.rfFE.service.type }}
  ports:
    - port: {{ .Values.rfFE.service.port }}
      targetPort: http
      protocol: TCP
      name: http
    - port: 8090
      targetPort: caddy
      protocol: TCP
      name: caddy
  {{- if not .Values.config }}
    - port: 5000
      targetPort: api
      protocol: TCP
      name: api
  {{- end }}
  selector:
    {{- include "rf-service.selectorLabels" . | nindent 4 }}
{% endhighlight %}

and ingress. Expose over ingress became mandatory to allows easy handling on frontend side with paths /caddy/ and /api/. This is exactly why rf-service api needs to have /api/ prefix. Caddy /caddy/ path is handled by using rewrite (see `.Values.caddy.setup` and snippet below).

{% highlight yaml %}
  rules:
  {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          - path: "/"
            backend:
              serviceName: {{ $fullName }}-rf-service
              servicePort: {{ $svcPort }}
          - path: "/caddy/"
            backend:
              serviceName: {{ $fullName }}-rf-service
              servicePort: 8090
        {{- if not $.Values.config }}
          - path: "/api/"
            backend:
              serviceName: {{ $fullName }}-rf-service
              servicePort: 5000
        {{- end }}
  {{- end }}
{% endhighlight %}

{% highlight yaml %}
    # Bind address
    :8090

    tls off
    log stdout
    errors stderr

    # After this line, all other paths are relative to root.
    root /tmp/store
    browse /

    rewrite /caddy/ {
      to /{file} /
    }
    upload /uploads {
      to "/tmp/store"
    }
{% endhighlight %}

<small markdown="1">[Back to table of contents](#toc)</small>

## Conclusions

The created frontend doesn't have styling and still needs some more work, but building it with Vue.js was real fun. After getting the whole idea of components it was quite easy to add new stuff there. Solutions to most of my initial problems could be found in great Vue.js materials or on forums. Vue.js is really great tool for creating both simple and complex apps and it is definitely a lot of learning ahead of me in this matter.

<small markdown="1">[Back to table of contents](#toc)</small>
