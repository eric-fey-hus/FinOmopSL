# FinOmopSL

## Starting SL

This refers to the split solution. 
Assumptions: 
  - RP VM with nginx and spire already running.
  - APLS running and license installed

1. On the RP VM:  
   Generate the JOINTOKEN as follows:
   ```sh
   docker exec spire-server /opt/spire/bin/spire-server token generate -spiffeID spiffe://hus.org/agent
   ```
   using the appropriate `spiffeID` instead of `spiffe://hus.org/agent`
   
2. On the ML VM:  
   Start all the docker containers of the SL framework. The `run.sh` script facilitates this:
   ```sh
   run.sh JOINTOKEN
   ```
   IMPORTANT:
   1. In the `run.sh` script configure the IP addresses as appropriate for your organization. 
   The provided file is the config for HUS, see lines 5-7 for  `DNSIP` and `APLSIP`, and `MLVMIP` for the IP of your ML VM. 
   2. Also search-and-replace "hus.org" as appropriate for your organization. 
   3. You might also need to adapt `swop/swop_profile.yaml`, replacing IPs and "hus.org" as appropriate for your organization

   The script will:
     - Start the DNS server, swarm-bind9, and configure the corresponding name resolution and IPs.
     - Generate a spire `agent.conf` file including the JOINTOKEN from a template file.
     - Start the SPIRE agent
     - Start the SN node
     - Start the SWOP node
   Note that the SWCI node will not be started. If you are the sentinel node (HUS),
   use `run_sentinel.sh` instead. At the end of the script, 
   this will also start the SWCI using a init script (`swci/swci-init`) that runs the build and run tasks.

3. SL should now be up and running. You can monitor task execution using
   ```sh
   docker logs swop-hus.org
   ```
   where `swop-hus.org` should be replaced by the appropriate container name for your institution.  

## Current best practices for SL projects.

Your SL project should have these folders:

- model: contains model file (python), shared
- data: private data (copy private data for model training into here)
- result: for saving trained model, shared
- swci: taskdefs and swci_init files (yaml)
- swop: swop_profile (yaml)

Private data in data/ are mounted as follows:
Source: `privatedata` field of SWOP profile
Mount: `PrivateContent` field in the run task definition

Shared data are mounted in the task definition file.

Every folder that you want to access in the containers have to be mounted. 
Similarly only files in mounted folders are available on the host. 
This is why we mount all three folders:


| host | container | type | 
| --- | --- | --- | 
| model | /tmp/model | shared |
| data | /tmp/model | private |
| result | /tmp/result | shared |

Example: Private mount:


## Example: Shared mount:

The following will result in the folders data and result to become available for the model training running in the container spawned by the task. 
  - As far as the model (model code) is concerned, the data are in /tmp/data and the results can be written to /tmp/result. 
  - Location on the host: /opt/hpe/swarm-learning/projects/FinOmopSL/data/ and /opt/hpe/swarm-learning/projects/FinOmopSL/result, respectively
    
taskdef/run.yaml
``` yaml 
Name: run
TaskType: RUN_SWARM
Author: Eric
Prereq: build_pycox
Outcome: run
Body:
    Command: model/test_v2.1.py
    Entrypoint: python3
    WorkingDir: /tmp
    Envvars: ["MODEL_DIR": model, "MAX_EPOCHS": 100, "MIN_PEERS": 1]
    PrivateContent: /tmp/data
    SharedContent:
    -   Src: /opt/hpe/swarm-learning/projects/FinOmopSL/model
        Tgt: /tmp/model
        MType: BIND
    -   Src: /opt/hpe/swarm-learning/projects/FinOmopSL/result
        Tgt: /tmp/result
        MType: BIND
```

## Example private mount

Define the source (folder on the host) in the swop profile yaml file, and the mount (in the container) in the task definition yaml file as shown below.

- As far as the model is concerned, the private data are available in /tmp/data.
- On the host the data are in /opt/hpe/swarm-learning/projects/FinOmopSL/data.

swop/swop_profile
``` yaml 
...
nodes :
    ...
    - slnodedef :
        privatedata :
            src: /opt/hpe/swarm-learning/projects/FinOmopSL/data
            mType : BIND
    ...
```

taskdef/run.yaml
``` yaml
...
Body: 
    ...
    PrivateContent: /tmp/data
    ...
```

Starting containers
---

1. When starting containers, they need to have the right labels

    - SWCI: `--label type=swci`

2. The joinToken for spiffe expires after 10 min.
    - To start the sn and swop containers the joinToken needs to be valid.
    - it looks like the swci container can be started and run and init script also after that.
    - the spiffe agent also needs the joinToken and that should be configured in the `spire-agent/agent_conf` file.
        -  here this is archived by providing `spire-agent/agent_conf.template` file that contains the placeholder `<JOIN-TOKEN>`
        -  This replaces the `<JOIN-TOKEN>` assuming that the env variable `joinToken` contains the join token:
            ```
            sed -f - "spire-agent/agent.conf.template" > spire-agent/agent.conf << _EOF
            s/<JOIN-TOKEN>/${joinToken}/g
            _EOF
            ```
        - The join token has to be generated on the rp VM by the spire-server:
            ```
            docker exec spire-server /opt/spire/bin/spire-server token generate -spiffeID spiffe://hus.org/agent
            ```
