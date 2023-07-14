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

Every folder that you wnat to acess in the containters have to be mounted. 
Similary only files in mounted folders are availabe on the host. 
This is why we mount all three folders:


| host | container | type | 
| --- | --- | --- | 
| model | /tmp/model | shared |
| data | /tmp/model | private |
| result | /tmp/result | shared |

Example: Private mount:


Example: Shared mount:


