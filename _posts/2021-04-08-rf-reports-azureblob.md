---
layout: page
#
# Content
#

title: "Publishing RobotFramework reports in Azure Blob Storage"
teaser: "In this article I'm describing new functionality added to rf-service - publishing RobotFramework reports in Azure Blob Storage."
categories:
  - articles
  - robotframework
tags:
  - Azure
  - testing
  - rf-service
  - RobotFramework

image:
  homepage: "rf-reports-azureblob.jpg"
  thumb: "rf-reports-azureblob.jpg"
  header: "rf-reports-azureblob.jpg"
  title: "rf-reports-azureblob.jpg"
---
In a long way off goal of making [rf-service](https://github.com/devopsspiral/rf-service) covering everything between writing tests and viewing test results I decided to work a little more on where the test reports could  be published. Using managed service for that seems to be perfect choice, especially if you could handle it in a 'send and forget' manner. In my work we are using Azure extensively so Azure Blob storage with its static website hosting is what I decided to use. In this article you will find very basic introduction to static web hosting on Azure and how you can send Robot Framework reports there programmatically. 

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

[Intro to Vue.js. Testing on kubernetes - rf-service frontend](https://devopsspiral.com/articles/k8s/robotframework-service-fe/) - adding frontend to the rf-service.

[Testing with octopus](https://devopsspiral.com/articles/k8s/testing-with-octopus/) - using Octopus project for test execution.

<small markdown="1">[Back to table of contents](#toc)</small>

## Azure Blob Storage static website hosting

Azure blob storage is a great way of keeping files in cloud. It's a simplified abstraction of file system with API allowing to configure things like retention, access control, redundancy etc. It is part of more general concept - storage account - which can be used for services like queues, tables or even big data scenarios like Data Lake storage.

### Creating blob storage and static website

Creating blob storage is pretty easy, as a prerequisite, you need to have resource group in place, as a container for your storage account. Depending on the requirements you can select performance, account type and proper replication level. I will go with the defaults. 

![Creating Storage Account V2](/images/rf-report-blob/rf-blob-sa.png)

After storage account is ready to be used, just go to Static website and enable the feature. This is exactly the thing that will make Robot Framework html reports to be visible as a website. You don't need to set index or error document in this case, we won't be really serving any startpage or anything like this, just the reports. It is good to take note of the primary endpoint, this is the URL under which your content will be served.

![Enabling static website](/images/rf-report-blob/static-website.png)

Enabling static website will create *$web* container, which is kind of root of everything you want to publish.

![Web container](/images/rf-report-blob/containers.png)

Now the important part, by default static websites are public - even though blob storage is by default not accessible publicly the $web container is handled differently (it supposed to be serving website ). You can limit the access to it in different ways, in corporate environment you would probably have private network connecting your work environment with Azure, network of internal/public IPs, etc. There is quick and easy way to limit the access only to your PC though, you can get back to storage account level, go to Networking and allow access from selected networks and use button to add client IP address. This will configure firewall to let in only your IP (remember that this IP may change depending on how exactly you are connecting to the internet).

![Web container](/images/rf-report-blob/firewall.png)

<small markdown="1">[Back to table of contents](#toc)</small>

## Changes in rf-service
Looking at the rf-service changes, simply new publisher called AzureBlobPublisher is available.

{% highlight bash %}
usage: rf-service [-h] [-i INCLUDE_TAGS] [-e EXCLUDE_TAGS]
                  [--AzureBlobPublisher-connection_string AZUREBLOBPUBLISHER_CONNECTION_STRING]
                  [--AzureBlobPublisher-path AZUREBLOBPUBLISHER_PATH]
                  [--AzureBlobPublisher-prefix AZUREBLOBPUBLISHER_PREFIX]
                  [--AzureBlobPublisher-blob_url AZUREBLOBPUBLISHER_BLOB_URL]
                  [--CaddyPublisher-url CADDYPUBLISHER_URL]
                  [--LocalPublisher-dest LOCALPUBLISHER_DEST]
                  [--LocalFetcher-src LOCALFETCHER_SRC]
                  [--ZipFetcher-url ZIPFETCHER_URL]
                  [--ZipFetcher-path ZIPFETCHER_PATH]
                  [config_file]

RobotFramework service.

positional arguments:
  config_file           JSON config file

optional arguments:
  -h, --help            show this help message and exit
  -i INCLUDE_TAGS, --include INCLUDE_TAGS
                        Include test tags
  -e EXCLUDE_TAGS, --exclude EXCLUDE_TAGS
                        Exclude test tags
  --AzureBlobPublisher-connection_string AZUREBLOBPUBLISHER_CONNECTION_STRING
  --AzureBlobPublisher-path AZUREBLOBPUBLISHER_PATH
  --AzureBlobPublisher-prefix AZUREBLOBPUBLISHER_PREFIX
  --AzureBlobPublisher-blob_url AZUREBLOBPUBLISHER_BLOB_URL
  --CaddyPublisher-url CADDYPUBLISHER_URL
  --LocalPublisher-dest LOCALPUBLISHER_DEST
  --LocalFetcher-src LOCALFETCHER_SRC
  --ZipFetcher-url ZIPFETCHER_URL
  --ZipFetcher-path ZIPFETCHER_PATH
{% endhighlight %}

It has 4 parameters described as:

* **connection_string** - connection string taken from storage account Access keys (see below picture)
* **path** - path in the $web container, can be used for grouping reports
* **prefix** - prefix for the target report, can be used for test type distinction
* **blob_url** - entirely informative parameter. Blob url along with path and prefix will write complete report url in logs

![Container string source](/images/rf-report-blob/connection_string.png)

Example test execution with publishing reports in Azure Blob Storage would look similar to:

{% highlight bash %}
./src/scripts/rf-service --AzureBlobPublisher-path some/path/ --AzureBlobPublisher-prefix smoke --AzureBlobPublisher-connection-string 'DefaultEndpointsProtocol=...' --LocalFetcher-src test/resources/testcases/
{% endhighlight %}

And the report would be published under [https://v2generalpurpose.z20.web.core.windows.net/some/path/smoke15-03-21T175232-662444.html](localhost)

<small markdown="1">[Back to table of contents](#toc)</small>

### Sending reports to Azure using Python
It is worth to go through the Python code that is responsible for sending the reports in case you want to use it outside the rf-service.

{% highlight python %}
    def _publish(self, result):
        reportname = self.get_standard_reportname()
        upload_file_path = f'/tmp/{reportname}.html'
        ResultWriter(result).write_results(report=upload_file_path,
                                           log=None)
        blob_service_client = BlobServiceClient.from_connection_string(self.connection_string)
        container_name = "$web"
        target_blob = f"{self.path or ''}{self.prefix or ''}{reportname}.html"
        blob_client = blob_service_client.get_blob_client(container=container_name, blob=target_blob)

        static_html_content_settings = ContentSettings(content_type='text/html')
        with open(upload_file_path, "rb") as data:
            blob_client.upload_blob(data, content_settings=static_html_content_settings)
        self.publish_target = f'{self.blob_url or ""}/{target_blob}'
{% endhighlight %}

Going from top to bottom, first of all I'm writing Robot Framework report to file which then will be uploaded to Azure Blob storage. Then, there is part containing initialization of blob service client and setting target blob path and name. Remember to set content settings to 'text/html' to make sure that report is rendered as static page. Last step is just sending the content and viewing the url of the published report.

<small markdown="1">[Back to table of contents](#toc)</small>

## Conclusion

Azure blob storage is an interesting option for keeping Robot Framework reports. There are couple of functionalities like retention, tagging, access control that can be configured for your reports but were not described in this article, but even without it, simple publishing in managed service is very convenient. Microsoft makes sure that API for blob storage is accessible through different programming languages like Python, JavaScript, Ruby and others so it can become storage for different kind of automation.

<small markdown="1">[Back to table of contents](#toc)</small>
