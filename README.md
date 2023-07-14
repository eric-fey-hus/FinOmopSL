# FinOmopSL

Current best practises for SL projects.

Your SL project should have these folders:

- model: contains model file (python), shared
- data: private data (copy provate data for model training into here)
- result: for saving trained model, shared
- swci: taskdefs and swci_init files (yaml)
- swop: swop_profile (yaml)

Private data in data/ are mounted as follows:
Source: `privatedata` field of SWOP profile
Mount: `PrivateContent` field in the run task definition

Shared data are mounted in the task definition file.

Every folder that you wnat to acess in the containers have to be mounted. 
Similary only files in mounted folders are availabe on the host. 
This is why we mount all three folders:


| host | container | type | 
| --- | --- | --- | 
| model | /tmp/model | shared |
| data | /tmp/model | private |
| result | /tmp/result | shared |

Example: Private mount:


## Example: Shared mount:

The following will result in the folders data and result to become available for the model training running in the container spawnd by the task. 
  - As far as the model (model code) is concerned, the data are in /tmp/data and the results can be writte to /tmp/result. 
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
 


