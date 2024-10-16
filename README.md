A stable and controlled by code role-based permissions management system for organizations


Access to all resources of Harmony Connect needs to be given by role base access RBAC 

By 4 main roles flat groups all area is divided:

admins-flat

operations-flat

developers-flat

readonly-flat


Those 4 role based AD and Azure AD flat groups need to be added to other groups that give access to any resources

Those 4 groups are very stable to any organizational changes, synced automatically, and the whole process is managed by the DevOps team only.

The groups are synced from the appropriate AD groups ( readonly, operations, developers, admins ) which are filled by real ORG HR groups 

The groups are synced automatically by pipeline

New relevant employees are added to operations and admins after 10 days in the company automatically, no need to open tickets

To allow users to learn before they get PRD access

Read-only access is given immediately


Groups below are managed by DevOps TL.

In case of reorg or adding new people, the TL must manually edit those groups and add/remove the relevant groups/ppl.

People not from the area need to open tickets to be members of the appropriate group:

DevOps TL approves/disapproves the request

readonly 
operations
developers
admins
