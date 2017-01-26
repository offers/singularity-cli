## 0.0.2 (2017-01-26)
Features:
  - Running the tool from a non-project directory now returns a nicer error message
  - Now changes the docker image SSH config to have a TCP keepalive for long SSH sessions
  
Bugfixes:
  - Fixes SSH errors when users have keys stored in non-.pem files
    
## 0.0.1 (2017-01-19)
Features:
  - OPS-229 run command returns container exit status code
  - OPS-239 ssh command generates its own config from all keys (fixes issues on Macs)
  
Bugfixes:
  - OPS-242 non-zero exit code no longer throws an exception
