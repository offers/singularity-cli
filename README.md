# singularity-cli

## Requirements
 * Docker >= 1.12.1
 * ~/.ssh/ configured with the right keys

## Install
```
docker pull offers/singularity-cli:latest
```

## Env Setup
Add the following line to your ~/.bashrc:

```
alias singularity='docker run --rm -e SINGULARITY_USER=`whoami` -v `pwd`:/pwd -v ~/.ssh:/ssh -it offers/singularity-cli:latest /usr/src/app/bin/singularity'
```

# Usage:
singularity deploy &lt;uri&gt; &lt;file.json&gt; &lt;release&gt;
* deploy singularity job

singularity delete &lt;uri&gt; &lt;file.json&gt;
* delete singularity deploy

singularity run &lt;commands&gt;
* start new container in singularity and run &lt;commands&gt;
* (do this from the base project folder of the box you wish to start)

singularity runx &lt;commands&gt;
* same as "singularity run" without use of /sbin/my_init
    
singularity ssh
* start new container in singularity and SSH into it

# Testing:
```
./test.sh
```

