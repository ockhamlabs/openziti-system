Migration workflow
This workflow only works as long as the naming of all resources - certs, helm release names and namespaces - are equal to the "old" installation !

Backup
In old controller Pod run:

ziti agent controller snapshot-db

Copy db snapshot form pod to local:

kubectl cp openziti/openziti-base-controller-c46c64b69-vrm4p:/persistent/ctrl.db-20231017-142051 ctrl.db-20231017-142051

Backup openziti-base-controller-admin-secret:

kubectl get secret/openziti-base-controller-admin-secret -o yaml > openziti-base-controller-admin-secret.yaml

Backup pvc config openziti-base-controller:

kubectl get pvc/openziti-base-controller -o yaml > openziti-base-controller.yaml

Backup certs and issuers:

kubectl get -n openziti -o yaml issuer,cert > backup.yaml

Backup secrets for certs and issuers:

openziti-base-controller-admin-client-secret
openziti-base-controller-ctrl-plane-identity-secret
openziti-base-controller-ctrl-plane-intermediate-secret
openziti-base-controller-ctrl-plane-root-secret
openziti-base-controller-edge-root-secret
openziti-base-controller-edge-signer-secret
openziti-base-controller-web-identity-secret
openziti-base-controller-web-intermediate-secret
openziti-base-controller-web-root-secret
Backup secrets for router enrollments and respective identities

openziti-routers-router1-identity
openziti-routers-router1-jwt
openziti-routers-router2-identity
openziti-routers-router2-jwt
Be sure to delete annotations, labels, and creationTimeStamp, ownerReferences, resourceVersion, uid from secrets and certs/issuers before running kubectl apply on the new K8s cluster!

Restore
Controller
Deploy openziti-base-controller-admin-secret.yaml to new cluster

kubectl apply -f openziti-base-controller-admin-secret.yaml
Deploy pvc to new cluster, mount it to busybox and transfer db backup to it!

Run busybox pod to be able to copy db file to PV
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
kubectl apply -f busybox-pvc-controller.yaml
kubectl cp ctrl.db-20231017-142051 openziti/volume-debugger:/persistent/ctrl.db
Check if the db file is there

kubectl exec -it pod/volume-debugger -- /bin/sh
Delete the busybox-pvc debugger

kubectl delete -f busybox-pvc-controller.yaml
Add existing pvc claim to openziti controller chart!

Run openziti-base helm chart

Override certs, issuers and secret resources with backups

kubectl apply -f certs_issuers/
kubectl apply -f controller-secrets/
Should the domain-names for the controller APIs have changed, some certs need to be renewed in the cert-manager:

´´´cmctl renew openziti-base-controller-web-identity-cert --namespace=openziti´´´
´´´cmctl renew openziti-base-controller-ctrl-plane-identity --namespace=openziti´´´
Restart OpenZiti controller - delete and it will be recreated

Router(s)
Deploy routers via helm
(Delete old Router identities in ZAC)
Create new identities for Router1 & Router2
Add the JWT enrollment token to the respective .values.yaml file!
Reusing the router identity(ies) is not intended by the router helm chart!
This is for sure not complete, but it is a starting point :slight_smile: