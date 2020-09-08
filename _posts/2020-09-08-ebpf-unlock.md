---
layout: page
#
# Content
#

title: "Unlocking eBPF power"
teaser: "My first steps with eBPF. In this article I'm describing how I used bluetooth tracing with eBPF to handle locking of my laptop."
categories:
  - articles
  - linux
tags:
  - ebpf
  - tracing
  - linux

image:
  homepage: "ebpf-unlock.jpg"
  thumb: "ebpf-unlock.jpg"
  header: "ebpf-unlock.jpg"
  title: "ebpf-unlock.jpg"
  caption: 'Image by <a href="https://pixabay.com/users/1681551-1681551/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=1220052">Robert Armstrong</a> from <a href="https://pixabay.com/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=1220052">Pixabay</a>'
---
I heard "eBPF" so many times in recent days that I've decided to give it a try. I have very limited knowledge about kernel tracing so I thought it is good opportunity to learn something new. One particular [talk](https://youtu.be/16slh29iN1g) (by Brendan Gregg) especially caught my attention and I recommend it if you want to get some general idea behind eBPF. At the beginning of his talk he is showing how he was able to monitor WiFi signal strength with eBPF. I seemed so easy that I wanted to mimic something similar. In this article I'm describing how I used eBPF tracing for locking and suspending my laptop using Bluetooth on my phone.

<div class="panel radius" markdown="1">
**Table of Contents**
{: #toc }
*  TOC
{:toc}
</div>

## So what is really eBPF?
There are many good sources to explain it along with the history of BPF (some of them you will find in this article), so I will try to make it simple. 

eBPF is a functionality of linux kernel that allows lightweight execution of user code as a response to kernel events. The events could be hardware/software events, tracing events both static (compiled into code) and dynamic (attached in runtime), etc. The code itself is limited in a sense that it is guaranteed to finish (no loops) and is verified before loading into kernel. 

Some facts and how others describes it:

* "Function-as-a-Service for kernel events" (Dan Wendlandt from his [talk](https://youtu.be/7PXQB-1U380))
* "Superpowers are coming to Linux" (Brendan Gregg from hist [talk](https://www.facebook.com/watch/?v=1693888610884236&extid=gOZRPKYFuuClz71r))
* Alternative for service mesh [Webinar: Comparing eBPF and Istio/Envoy for Monitoring Microservice Interactions](https://youtu.be/Wocn6DK3FfM)
* Cilium which uses eBPF as a foundation, was recently announced GKE networking dataplane. 
* kubectl has trace plugin for scheduling bpftrace programs
* Android has eBPF loader

<small markdown="1">[Back to table of contents](#toc)</small>

## Bluetooth case

At the beginning the only thing I knew is that I need to trace Bluetooth. But how should I know what are the function names that are called? Recalling some basic knowledge about linux kernel: kernel is the interface between user programs and hardware > kernel uses kernel modules that are specific for particular hardware > I should probably find Bluetooth module then. So by listing loaded modules I could find at least some anchor to begin with.

{% highlight bash %}
$ lsmod
Module                  Size  Used by
(...)
bluetooth             573440  117 btrtl,btintel,btbcm,bnep,btusb,rfcomm
{% endhighlight %}

Shockingly enough, the module I was looking for is named Bluetooth :). Turns out that with this information we can already limit tracing to specific module using trace-cmd. It is a wrapper around ftrace tracer, which in raw form requires writing values into filesystem. You can install it using something similar to `apt-get install -y trace-cmd`. Then you can actually use it for tracing functions of a specific module.

{% highlight bash %}
$ trace-cmd record -p function -l ':mod:bluetooth'
  plugin 'function'
Hit Ctrl^C to stop recording
^CCPU0 data recorded at offset=0x671000
    4096 bytes in size
CPU1 data recorded at offset=0x672000
    4096 bytes in size
CPU2 data recorded at offset=0x673000
    0 bytes in size
CPU3 data recorded at offset=0x673000
    0 bytes in size
{% endhighlight %}

Seeing that there are non-zero bytes captured is always a good sign. To view the output you need to issue *report* command.

{% highlight bash %}
$ trace-cmd report

kworker/(...) 85164.256606: function:              process_adv_report
kworker/(...) 85164.256607: function:                 hci_find_irk_by_rpa
kworker/(...) 85164.256608: function:                 has_pending_adv_report
kworker/(...) 85164.256609: function:                 mgmt_device_found
kworker/(...) 85164.256610: function:                    hci_discovery_active
kworker/(...) 85164.256612: function:                    link_to_bdaddr.part.10

{% endhighlight %}

<small markdown="1">[Back to table of contents](#toc)</small>

## Into the eBPF

At this point I had a bunch of function calls, that I should use to somehow get the useful info about my phone's Bluetooth state. You can find code of all the functions in kernel source code so in theory it should be matter of time to find the right one to trace. Well, it was pretty significant matter of time, spent on recalling C basics, HCI protocol events and bpftrace, which is what I wanted use in the end.

So how the trial and error part looked like? I had to first install bpftrace from snap and overcome lockdown (see [this issue](https://github.com/iovisor/bpftrace/issues/853)). You need to run all those commands as root too.

{% highlight bash %}
$ snap install bpftrace
$ snap connect bpftrace:system-trace
{% endhighlight %}

I used kprobe, which is the kernel debugging mechanism that can be attached to function execution. Whenever function is entered you can access all its arguments (in bpftrace). So for example let's say we want to trace *hci_cmd_complete_evt*, defined as:

{% highlight c %}
static void hci_cmd_complete_evt(struct hci_dev *hdev, struct sk_buff *skb,
				 u16 *opcode, u8 *status,
				 hci_req_complete_t *req_complete,
				 hci_req_complete_skb_t *req_complete_skb)
{
{% endhighlight %}

As you can see, there is hdev argument of type hci_dev which turns out to be structure holding a lot of information about the Bluetooth device. Let's have a look just at the top fields of this struct.

{% highlight c %}
struct hci_dev {
	struct list_head list;
	struct mutex	lock;

	char		name[8];
{% endhighlight %}

Knowing all above, I could print the name of local device using below script.

{% highlight bash %}
# bt_dev_read.bt
1 #!/snap/bin/bpftrace
2 
3 #include <net/bluetooth/bluetooth.h>
4 #include <net/bluetooth/hci_core.h>
5 
6 
7 kprobe:hci_cmd_complete_evt
8 {
9 $dev=( struct hci_dev *) arg0;
10 printf("%s\n", $dev->name);
11 }

{% endhighlight %}

So yes, bpftrace has its own language similar to C but consisting of only group of functions (see [reference guide](https://github.com/iovisor/bpftrace/blob/master/docs/reference_guide.md#bpftrace-reference-guide)]). It is often used in a form of one-liners, but you can put it into file with shebang as I did.

Going through the code, we need to first include kernel headers (lines 3-4) which is used to cast arg0 into hci_dev struct (line 9). In line 7, I'm attaching the code to kprobe:hci_cmd_complete_evt, which is eBPF at its beauty - you can execute your own code in kernel as a reaction to kernel event. In this case the reaction is just printing device name (line 10) every time *hci_cmd_complete_evt* function is entered. After running it you should see new line with device name every few seconds.

{% highlight bash %}
# bt_dev_read.bt
$ ./bt_dev_read.bt 
Attaching 1 probe...
hci0
hci0
hci0
hci0

{% endhighlight %}

I had to also make sure that the target function is triggered frequently enough, so I found more usable function called *mgmt_device_found* that had all I need: MAC address (arg1) and RSSI (Received Signal Strength Indication - arg5).

{% highlight c %}
void mgmt_device_found(struct hci_dev *hdev, bdaddr_t *bdaddr, u8 link_type,
		       u8 addr_type, u8 *dev_class, s8 rssi, u32 flags,
		       u8 *eir, u16 eir_len, u8 *scan_rsp, u8 scan_rsp_len)
{
{% endhighlight %}

Even though bpftrace support array *[]* operator I had problems reading correctly bdaddr struct with its underlying array, so I end up using C trick of incrementing pointer to array directly. You can find more details in below snippet - I divided MAC into to halves and then put it back in printf. I'm also printing rssi after a space in same line.

{% highlight bash %}
# bt_rssi.bt
#!/snap/bin/bpftrace

kprobe:mgmt_device_found
{
$mac1=*(arg1+3) & 0xffffff;
$mac2=*(arg1) & 0xffffff;
printf("%X%X %d\n", $mac1,$mac2, arg5);
}

{% endhighlight %}

The output from running this code looks as follows.

{% highlight bash %}
$ ./bt_rssi.bt 
Attaching 1 probe...
7AC8715201FD -75
C2C62D1EC7 -79
30144A848783 -87
C2C62D1EC7 -82
{% endhighlight %}

As a result I have per MAC signal strength that I can later on use to trigger lock and unlock of my Ubuntu system. That is great, but why not find disconnect function that would trigger system suspend whenever I disable Bluetooth on my phone. Fortunately it is there and its called *mgmt_device_disconnected* the bpftrace to output disconnected MAC can be found below.

{% highlight bash %}
# bt_disconnect.bt
#!/snap/bin/bpftrace

kprobe:mgmt_device_disconnected
{
$mac1=*(arg1+3) & 0xffffff;
$mac2=*(arg1) & 0xffffff;
printf("%X%X\n", $mac1,$mac2);
}
{% endhighlight %}

<small markdown="1">[Back to table of contents](#toc)</small>

## System lock and suspend handling

We have now bt_rssi.bt showing MAC with corresponding signal power and bt_diconnect.bt showing MAC that just disconnected. It is time to shell-script it into actual system actions.

{% highlight bash %}
# bt_handler.sh
1 #!/usr/bin/env bash
2 TARGET_MAC=$1
3 LOCKFILE=bt.lock
4 
5 bt_lock() {
6 args=($1)
7 if [ "${args[0]}" == "$TARGET_MAC" ]
8 then
9   if [ "${args[1]}" -lt -75 ] && [ ! -f "$LOCKFILE" ]
10   then
11     >"$LOCKFILE"
12     echo "locked"
13     loginctl lock-sessions
14   fi
15   if [ "${args[1]}" -gt -65 ] && [ -f "$LOCKFILE" ]
16   then
17     rm -f "$LOCKFILE"
18     echo "unlocked"
19     loginctl unlock-sessions
20   fi
21 fi
22 }
23 
24 export TARGET_MAC
25 export LOCKFILE
26 export -f bt_lock
27 
28 ./bt_disconnect.bt | grep --line-buffered "$TARGET_MAC" | xargs -r -n1 bash -c ">$LOCKFILE; /bin/systemctl suspend" &  
29 ./bt_rssi.bt | xargs -r -n1 -I '{}' bash -c 'bt_lock "$@"' _ {}

{% endhighlight %}

The script takes only one argument - target MAC address (i.e. your phone Bluetooth MAC) and uses LOCKFILE file to mark if system is locked already. *bt_lock()* function parses the output of bt_rssi.bt to decide on locking or unlocking the session. Because xargs in line 29 passes one argument in form "\<MAC\> \<RSSI\>", it needs to be broken into two arguments using bash array in line 6.

Since xargs starts a separate process I had to export all the variables and function in lines 24-26. Last two lines of the script are just actual executions of bpftrace scripts. 

After running the whole script with Bluetooth working on both your pc and phone, you should see system being locked whenever you go away for ~2 meters and unlocked when phone is back near the pc. Turing off the Bluetooth on your phone will result in suspend. The extra feature is that when you turn on the Bluetooth after suspend and wake pc up it becomes unlocked, all of that without typing the password.

<small markdown="1">[Back to table of contents](#toc)</small>

## Conclusion

Just remember that the script showed in this article was created for educational purposes (just for fun) and it shouldn't be used in places where you are exposed to anybody that could reach your keyboard. This is mainly because of the fact that your Bluetooth MAC becomes effectively password to your system, and despite of techniques that hides Bluetooth MAC it should be treated as public information. It works ok when using it at home, during pandemic, when the only hackers nearby are 2 and 6 years old and mostly using brute-force keyboard attacks, not Bluetooth MAC spoofing.

As for eBPF, it is definitely very interesting concept that gains adoption in multiple fields. Vision behind it is far broader than tracing, performance and security cases. eBPF against current service mesh implementations with all its significant overhead is something worth looking at closely.

<small markdown="1">[Back to table of contents](#toc)</small>
