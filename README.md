# singularity-cli
`singularity-cli` replaces the `mescal` command that Offers.com has used in the past
 * don't delete your `.mescal.json` yet (this tool uses it & `mesos-deploy` still updates it)
 * you can still use the `mesos-deploy` tool to deploy entire projects at once
 * all of the commands except `delete` and `deploy` require you to be in the base project folder to work correctly 

## Requirements
 * Docker >= 1.12.1
 * ~/.ssh/ configured with the right keys

## Install (or update to a new version)
```
docker pull offers/singularity-cli:latest
```

## Env Setup
Add the following line to your ~/.bashrc:

```
alias singularity='docker run --rm -e SINGULARITY_USER=`whoami` -v `pwd`:/pwd -v ~/.ssh:/ssh -it offers/singularity-cli:latest /usr/src/app/bin/singularity'
```

# Usage:
####singularity deploy &lt;uri&gt; &lt;file.json&gt; &lt;release&gt;
* manually deploy a single singularity job
 - example:
 ```
 cd ~/yourproject
 singularity deploy ./singularity/some-singularity-config.json r74
 ```

####singularity delete &lt;uri&gt; &lt;file.json&gt;
* delete singularity job
 - example:
 ```
 singularity delete ./singularity/some-singularity-config.json
 ```
####singularity run &lt;commands&gt;
* start new container in singularity and run &lt;commands&gt;
* for now, the commands (or script) must either be passed on the command line or in the container 
 - examples:
 ```
 cd ~/yourproject
 singularity run /your/script/is/here.sh args
 singularity run ls -a | grep appname
 ```
####singularity runx &lt;commands&gt;
* same as "singularity run" without use of /sbin/my_init
* generally don't use this command, it is just here in case /sbin/my_init gives you problems
 - example:
 ```
 cd ~/yourproject
 singularity runx /your/script/is/here.sh args
 ```
####singularity ssh
* start new container in singularity and SSH into it
 - example:
 ```
 cd ~/yourproject
 singularity ssh
 ```
# Creation of a new project:
If you want to create a new project that uses this tool's functionality you must create the files `.mescal.json` and `mesos-deploy.yml` in the base project directory. Use another project's files as a template and fill in the values for your new project.

# Testing:
```
./test.sh
```

