### configuration of the fsdb

During the installation process the User is asked to configure the fsdb on the basis of a default configuration (see [.scripts.config](https://gitlab.com/arnimjenett/fsdb23#scriptsconfig) below). As all of these variables are used as Linux-parameters, please make sure, that they **do not contain whitespaces**, as these are perceived as word delimiters in Linux. Capitalization is relevant and variables, which are populated with variables (which start this a dollar-sign($)) should not be tempered with.    
Here some details on the variables, which need to be configured:  
| Variable | Comment |
| --- | --- |
| ADMIN | This needs to be an existing, sudo-enabled account on the computer the fsdb is installed on. Ideally the account used for/during the installation of the fsdb. |
| CONSORTIUM | in the scope of data sharing between diffferent user groups (labs, units, GROUPs) this parameter may become useful as unix access permissions of users within the same (additional) group (CONSORTIUM) are easier to handle. |
| GROUP | This is the name of the unix-group of your user group. A good practise is to use the abbreviated name of your lab (e.g., tps for TEFOR Paris-Saclay ) |
| DEV | This is the name of the group of developers of the fsdb. Developers (defined in DEVACCOUNTS below) will be members of this group and by this wil have extended file access permissions in comparison to normal users (As defined in USERS below). |
| DEVACCOUNTS | Optionally this can be a space-delimited list of user account names, which shall have permission to modify your instance of the fsdb.  |
| ADMINACCOUNTS | Optionally this can be a space-delimited list of user account names, which have full access permissions to your instance of the fsdb.  |
| USERACCOUNTS | This is a space-delimited list of user account names. If they do not exist on the system, they will be generated during the setup process. |
| LAB | This should be short-name (without white-spaces or special characters!). It will be part of the file system structure (to separate (access permissions to) your data from these of other labs on the same instance of the fsdb) |
| USER | This is a space-delimited list of directory names on the image acquisition system(s) (IAS). These Directories must be located on the shared partition/drive of the ISA and will be accessed remotely from your fsdb. Not all directories listed here need to exist on all IAS. |
| DEBUGLEVEL | 0: silent, 1: some output, 2: very chatty |
| HOSTS | This is a comma-separated list of IP-addresses, which are granted access to your instance of the fsdb via samba.  |

The actions of the fsdb components can be configured in the component's configuration files. E.g., the output of the secondary-data-generation can be adjusted by modifying `fsdb23/scripts/sdg/sdg.config`. 
