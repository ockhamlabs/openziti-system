# Migration workflow


####  This workflow only works as long as the naming of all resources - certs, helm release names and namespaces - are equal to the "old" installation !

####  The main data is stored under pv such as 
- identities
- policies


#### The other part of data are under secrets , issuers and certs 
- secrets hold the auth info for ziti components to communicate
- issuers and certs need to be same to keep the syncronisation of new controller intact with other ziti components like the old controller


## Backup from existing setup

### In old controller Pod run:

 - ziti agent controller snapshot-db

 - Copy db snapshot form pod to local:

 ```sh 
kubectl cp openziti/openziti-base-controller-c46c64b69-vrm4p:/persistent/ctrl.db-20231017-142051 ctrl.db-20231017-142051
 ```

 - Backup openziti-base-controller-admin-secret:

 ```sh 
kubectl get secret/openziti-base-controller-admin-secret -o yaml > openziti-base-controller-admin-secret.yaml
```

 - Backup pvc config openziti-base-controller:

 ```sh 
kubectl get pvc/openziti-base-controller -o yaml > openziti-base-controller.yaml
```

### Backup certs and issuers:

 - kubectl get -n openziti -o yaml issuer,cert > backup.yaml

#### Which includes

- openziti-base-controller-admin-client-secret
- openziti-base-controller-ctrl-plane-identity-secret
- openziti-base-controller-ctrl-plane-intermediate-secret
- openziti-base-controller-ctrl-plane-root-secret
- openziti-base-controller-edge-root-secret
- openziti-base-controller-edge-signer-secret
- openziti-base-controller-web-identity-secret
- openziti-base-controller-web-intermediate-secret
- openziti-base-controller-web-root-secret
- openziti-routers-router1-identity
- openziti-routers-router1-jwt
- openziti-routers-router2-identity
- openziti-routers-router2-jwt

Be sure to delete annotations, labels, and creationTimeStamp, ownerReferences, resourceVersion, uid from secrets and certs/issuers before running kubectl apply on the new K8s cluster!

## Restore

- Deploy openziti-base-controller-admin-secret.yaml to new cluster

 ```sh 
kubectl apply -f openziti-base-controller-admin-secret.yaml
 ```

- Deploy pvc to new cluster, mount it to busybox and transfer db backup to it!

Run busybox pod to be able to copy db file to PV
```yaml 
kind: Pod
apiVersion: v1
metadata:
name: volume-debugger
spec:
volumes:
    - name: volume-to-debug
    persistentVolumeClaim:
    claimName: openziti-base-controller
containers:
    - name: debugger
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
        - mountPath: "/persistent"
        name: volume-to-debug
 ```

 ```sh       
kubectl apply -f busybox-pvc-controller.yaml
```

 ```sh 
kubectl cp ctrl.db-20231017-142051 openziti/volume-debugger:/persistent/ctrl.db
```

### Check if the db file is there

 ```sh 
kubectl exec -it pod/volume-debugger -- /bin/sh
```


### Delete the busybox-pvc debugger

 ```sh 
kubectl delete -f busybox-pvc-controller.yaml
```

### Add existing pvc claim to openziti controller chart!

### Run openziti-base helm chart

### Override certs, issuers and secret resources with backups

 ```sh 
kubectl apply -f certs_issuers/
 ```
 ```sh 
kubectl apply -f controller-secrets/
 ```


 ### Ideas to automate the process 

 ### use velero directly which can backup the entire resources externally , basically a cronjob with velero deployement should do the thing




