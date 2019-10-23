---
layout: page
#
# Content
#

title: "Githooks, awk and aspell - stirred, not shaken."
teaser: "In this article I'm explaining automation created by me that allows spell checking for articles in my jekyll site. I thought it is perfect occasion to give some introduction to githooks, awk and aspell."
header:
  background-color: "#4472c4"
  image: logo.png
  title: DevOps Spiral
categories:
  - articles
  - linux
tags:
  - jekyll
  - awk
  - githooks
image:
  homepage: "githooks-awk-aspell.png"
  thumb: "githooks-awk-aspell.png"
  header: "githooks-awk-aspell.png"
  title: "githooks-awk-aspell.png"
  caption: 'Based on Photo by <a href="https://www.pexels.com/@enginakyurt?utm_content=attributionCopyText&utm_medium=referral&utm_source=pexels">Engin Akyurt</a> from <a href="https://www.pexels.com/photo/close-up-photo-of-martini-in-cocktail-glass-2531195/?utm_content=attributionCopyText&utm_medium=referral&utm_source=pexels">Pexels</a>'
---
My site is hosted on GitHub pages, which I think is very good option to start your website. You get hosting, valid Let's Encrypt certificate, you can point your custom domain to it and your page is version controlled. It has also built-in support for jekyll, which can be used for templating your static files. It is also good idea to use ready-made theme that will cover all the inevitable configuration behind the scene (I'm using [feeling-responsive](https://phlow.github.io/feeling-responsive/)). You can still add some custom tweaks if you want. The end goal is just to focus on writing .md's with your content. Part of writing is also making sure that you are not making spelling mistakes, which happens not that rare for non-native speaker. I wanted to make spelling check kind of gateway to publishing my content and I thought using git hooks for that sounds like a good idea.

<div class="panel radius" markdown="1">
**Table of Contents**
{: #toc }
*  TOC
{:toc}
</div>

## Different types of client-side git hooks

Git hooks are just scripts that are executed by git for specific operations in the repository. This is a way how git as a version control system allows to fit its flows to your projects specifics. You can use it for things ranging from commit validation, environment setup or notifications. Any executable with proper name of the git hook in your repository *.git/hooks/* should work just fine.

Git hooks are divided into two groups: server-side and client-side, as you can imagine the first one works on git server, the second runs on your pc. I will focus on client-side hooks as those are the ones I used for my spell checking automation. I also did not include email workflow and git garbage collection hooks as they are used in specific context that is not touched in this article. In the table below you can find what is the use case for particular git hook. I thought putting it into table would be more easy to understand.

| git hook        | Use case           |
| -------------- |---------------|
| pre-commit     | Executed before adding commit message. Can be used for commit validation, linters etc. Non-zero exit code aborts operation.|
| prepare-commit-msg    | Executed just before writing commit message. Can be used to automatically create commit message. |
| commit-msg    | Executed *AFTER* writing commit message. Can be used to validate commit messages. Non-zero exit code aborts operation. |
| post-commit     | Executed after commit is done. Can be used for notifications. |
| pre-rebase    | Executed before rebase started. Can be used to check if rebase is allowed, i.e. commit was already pushed, which can cause split-brain on CI side when rebase rewrites commit history. Non-zero exit code aborts operation. |
| post-rewrite    | Executed after rewriting commit history (rebase, amend). Can be used to do some cleanup caused by his change.|
| post-checkout    | Executed after checkout. Can be used to setup environment, i.e. generate files that are not versioned but are needed for development. |
| post-merge    | Executed after merge. Can be used to setup environment, i.e. generate files that are not versioned but are needed for development. |
| pre-push    | Executed before actual transfer but after remote refs update. Can be used to validate result of the push. Non-zero exit code aborts operation.  |

Git hooks directory (*.git/hooks/*) has already *.sample* hooks that you can start from when creating your own scripts. You just need to remember to remove *.sample* part of the name and make the script executable. In this particular case I will use only *pre-commit* and *prepare-commit-msg* hooks to achieve what I planned. Let's start with spell checking task.

{% highlight bash linenos %}
# pre-commit
#!/bin/sh
changed=$(git diff --cached --name-status | grep -v '^D' |grep .md | awk '{print $2}')
for f in $changed
do
  ./splitter.awk $f
  for fcheck in *.content
  do
    [ "$fcheck" == "*.content" ] && exit
    if [ "$1" == check ]
    then
      aspell --home-dir=. --personal=dictionary.txt -H -x check $fcheck
    else
      misspelled=$(cat $fcheck | aspell --home-dir=. --personal=dictionary.txt -H list)
      for word in $misspelled
      do
        has_misspelled=1
        cat $fcheck | sed "s/$word/>>$word<</g" | grep --color $word
      done
    fi
  done
  ./joiner.sh $f
done
if [ -n "$has_misspelled" ]
then
  echo "====================================="
  echo "Commit aborted due to spelling mistakes. To force commit execute git commit --no-verify"
  exit 1
fi
{% endhighlight %}

[Source from Github](https://github.com/devopsspiral/devopsspiral.github.io/blob/master/pre-commit)

As you can see this is regular bash script, in line 3 I'm getting files that are included in the commit. This will list two column output with first column showing if file is deleted or added/updated. I'm only interested in the latter so I grep out *^D*. Then I'm filtering only *.md* files as those are the ones with actual content and as a last step I'm using 2nd column where the filenames are kept.

For each file, script is doing splitting in line 6. I will explain later how it is achieved, but the goal is to extract from *.md* files only parts with text, excluding code blocks. *splitter.awk* will produce *.header*, *.content* and *.hcode* files for YAML header, text and highlight code block respectively. Again script is only looping over **.content* files. Line 9 is just safety fuse to stop execution if there are no **.content* files. *pre-commit* script can also be run manually with *check* flag that allows interactive spell checking, this is done in line 12. In this particular githook aspell will be only used for listing misspelled words, all of which will be marked in respective lines both with color and *>><<* to make it visible in VS code terminal for example. Line 22 is doing exactly opposite job than *splitter.awk*, it will take all the pieces together. In *check* mode corrections are made inline, so after composing, result file should have all the corrections in place. Last part (lines 24-29) is aborting commit in case errors were found. You might want to force commit regardless of errors which can be done with *git commit \-\-no-verify*.

Just for reference I'm also including *joiner.sh*, which just takes all the *md\** files and place it in order back to original file. Notice that naming of partial files is not random, I made the name in such a way that *./md\** will get them in correct (alphabetical) order.

{% highlight bash %}
# joiner.sh
#!/usr/bin/env bash
set -e
>$1
for f in ./md*
do
	cat $f >> $1
	rm -f "$f"
done
{% endhighlight %}

[Source from Github](https://github.com/devopsspiral/devopsspiral.github.io/blob/master/joiner.sh)

The second git hook is much simpler and it is supposed to generate default commit message. When adding new article in my repo mostly it is one *.md* file with some image, so the name of the file makes perfect commit message, especially when it is descriptive, which is partly forced by jekyll. Code of *prepare-commit-msg* can be found below.

{% highlight bash %}
# prepare-commit-msg
#!/bin/sh
COMMIT_MSG_FILE=$1
COMMIT_SOURCE=$2
SHA1=$3

changed=$(git diff --cached --name-status | awk '{print $2}' | grep '.md')
if [ -n "$changed" ]
then
  filename=$(basename ${changed%% *})
  sed -i "1i$filename" "$COMMIT_MSG_FILE"
fi
{% endhighlight %}

[Source from Github](https://github.com/devopsspiral/devopsspiral.github.io/blob/master/prepare-commit-msg)

I is worth to notice that as first steps git is injecting some of the variables connected with this particular commit, which can be used to prepare commit message. In my case I will use only *$COMMIT_MSG_FILE* which is the place where you need to put the final message. Once again, my script analyses what are the files changed, takes 2nd column and filter only *.md* files. If they are any, script is taking only basename of the first *.md* file (in case there are many) and puts it as a first line in commit message file. Nothing too fancy but it covers most of my commits. In next section I will show the content of awk script.

<small markdown="1">[Back to table of contents](#toc)</small>

## AWK and splitter.awk

Not sure how often you are using awk, but for a long time it was a tool used only by some linux magicians. I guess reason for that was that mostly you find "awk one-liners" that are hard to remember but somehow works. To disenchant awk I had to understand that it is just powerful script language and "awk one-liners" are just quirky way of putting perfectly reasonable script into one line. You could expect the same effect when using bash script or any programming language packed in one line.

I will not go into too many details of awk as it wouldn't fit single section, but *splitter.awk* is good example of some basic features that can be used in day-to-day work.

{% highlight bash linenos %}
# splitter.awk
#! /usr/bin/awk -f
BEGIN {
	header = 1
	yaml_parts = 0;
	part_count = 0
	code = 0
}
{
if( $0 == "---")
	yaml_parts++;
else if( $0 ~ / highlight/)
	code = 1;
if( header )
	filename = "md000.header";
else if( code )
	filename = sprintf("md%.2d.hcode", part_count);
else
	filename = sprintf("md%.2d.content", part_count);
print >filename
if( yaml_parts == 2 )
	header = 0;
if ( $0 ~ / endhighlight/)
{
        code = 0;
        part_count++;
}
}
END {
}
{% endhighlight %}

[Source from Github](https://github.com/devopsspiral/devopsspiral.github.io/blob/master/splitter.awk)

First, note the shebang of the script, naturally awk is there but with *-f* flag any argument passed to the script becomes awk input. Script has 3 sections: BEGIN, main section and END. First and last one can be used for setup and teardown, they are executed only once. Main section is triggered per each line of input file by default.

In BEGIN I'm just initializing variables. The goal of lines 9-12 is to detect in which part of file the script is - YAML header or code block. Then lines 13-18 sets proper output filename and Line 19 is doing actual transfer of line into output file. In the last part I'm clearing header and code flags when needed and incrementing file count.

Pretty reasonable piece of code with variables, if statements and others. As awk is text processor it has some build-in variables like *$0* representing processed line and $1,$2,... which points to Nth column in particular line. You can also utilize advanced pattern matching, some of which (*$0 ~...*) was used to locate jekyll highlight block start and end.

<small markdown="1">[Back to table of contents](#toc)</small>

## Aspell

Last part that still needs some comment is aspell. Aspell is GNU spell checker that is almost certainly installed on your linux distro. I first used it when checking my master thesis written in LateX.

{% highlight bash %}
      aspell --home-dir=. --personal=dictionary.txt -H -x check $fcheck
    else
      misspelled=$(cat $fcheck | aspell --home-dir=. --personal=dictionary.txt -H list)
{% endhighlight %}

If you take a closer look at lines where it was actually used in my git hook, you will find out two basic commands *check* and *list*. First one is starting interactive UI where you can actually go through spelling errors and use some of the suggestions to correct them. List on the other hand, is just making a list of misspelled words. Aspell can also keep dictionary with exceptions, so that they will no longer be treated as errors. Dictionary is just text file that can be defined with `--home-dir=. --personal=dictionary.txt`, which is pointing into dictionary.txt in my repo root. *-x* flag is used to avoid backuping files that aspell changes which would end up with some leftovers in my repository. *-H* is telling aspell to use HTML mode that helps with omitting some of the inline HTML that I might use. There are other modes available like mentioned LateX.

<small markdown="1">[Back to table of contents](#toc)</small>

## Summary

Initially in this article I wanted to focus on git hooks but practical examples are always better choice for learning. The scripts I created are pretty simple, but can be easily extended to whatever you need. I also think git hooks are perfect way of putting into harness version control activities, such as lint checks. Sometimes those end up in CI but are more effective when used much closer to developer. All the scripts can be found in my [github pages repository](https://github.com/devopsspiral/devopsspiral.github.io).

<small markdown="1">[Back to table of contents](#toc)</small>
