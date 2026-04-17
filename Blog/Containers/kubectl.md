---
weight: 100
title: kubectl命令
slug: kubectl
description: 
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-04-17T10:04:40+08:00
lastmod: 2026-04-17T10:04:40+08:00
---
## 命令
### kubectl

#### kubectl get
`kubectl get`获取当前资源

```
kubectl get pod
    -A,--all-namespaces 查看当前所有名称空间的资源
    -n 指定命名空间,默认值是default(kube-system空间存放当前组件的资源)
    --show-labels 查看当前标签
    -l 筛选资源,key或key=vaule
    -L 显示所有pod,添加一列显示每个Pod的某个标签的值
    -o wide 展示详细信息,包括IP,分配的节点
    -o yaml 打印资源清单在etcd中的存储结果
    -w 监视,打印结果的变化状态
```

显示每个pod的app标签
```
[root@k8s-master01 ~]# kubectl get pod -L app
NAME                                     READY   STATUS    RESTARTS   AGE     APP
busybox                                  1/1     Running   0          5m19s   busybox
myapp-clusterip-deploy-5c9cc9b64-jcf87   1/1     Running   0          52m     myapp
myapp-clusterip-deploy-5c9cc9b64-kbljv   0/1     Running   0          52m     myapp
myapp-clusterip-deploy-5c9cc9b64-txht6   0/1     Running   0          52m     myapp
```
通过`-o yaml`参数查看资源的资源清单:
```
$ kubectl get pod pod-demo -o yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    cni.projectcalico.org/containerID: 9481acf9660920850cf0ff98fee1ec64b0f75f3157d357404270ab494b21616d
    cni.projectcalico.org/podIP: 10.244.109.68/32
    cni.projectcalico.org/podIPs: 10.244.109.68/32
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Pod","metadata":{"annotations":{},"labels":{"app":"myapp"},"name":"pod-demo","namespace":"default"},"spec":{"containers":[{"image":"wangyanglinux/myapp:v1.0","name":"myapp-1"},{"command":["/bin/sh","-c","sleep 3600"],"image":"wangyanglinux/tools:busybox","name":"busybox-1"}]}}
  creationTimestamp: "2026-04-17T00:01:21Z"
  labels:
    app: myapp
  name: pod-demo
  namespace: default
  resourceVersion: "40865"
  uid: 59f70fe0-b263-4bca-9f36-e5a4344a6d86
```
#### kubectl set
`kubectl set`设置资源

```
# 设置deployment的image,触发镜像更新(滚动更新)
kubectl set image deployment deployment-1 container=wangyanglinux/myapp:v2.0 
```
#### kubectl exec
`kubectl exec`进入容器

```
kubectl exec -it pod-demo -c myapp-1 -- /bin/bash
    -c 指定容器名称CName,如果只有一个容器可以省略
```
#### kubectl explain
查看资源的描述可以使用`kubectl explain 资源名称`

```
kubectl explain deployment
GROUP:      apps
KIND:       Deployment
VERSION:    v1

DESCRIPTION:
    Deployment enables declarative updates for Pods and ReplicaSets.

FIELDS:
  apiVersion    <string>
    APIVersion defines the versioned schema of this representation of an object.
    Servers should convert recognized schemas to the latest internal value, and
    may reject unrecognized values. More info:
    https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources

  kind  <string>
    Kind is a string value representing the REST resource this object
    represents. Servers may infer this from the endpoint the client submits
    requests to. Cannot be updated. In CamelCase. More info:
    https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds

  metadata      <ObjectMeta>
    Standard object's metadata. More info:
    https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata

  spec  <DeploymentSpec>
    Specification of the desired behavior of the Deployment.

  status        <DeploymentStatus>
    Most recently observed status of the Deployment.
```
还可以查看资源对象的字段,使用`kubectl explain 资源名称.字段`
```
kubectl explain deployment.spec

GROUP:      apps
KIND:       Deployment
VERSION:    v1

FIELD: spec <DeploymentSpec>

DESCRIPTION:
    Specification of the desired behavior of the Deployment.
    DeploymentSpec is the specification of the desired behavior of the
    Deployment.

FIELDS:
  minReadySeconds       <integer>
    Minimum number of seconds for which a newly created pod should be ready
    without any of its container crashing, for it to be considered available.
    Defaults to 0 (pod will be considered available as soon as it is ready)

  paused        <boolean>
    Indicates that the deployment is paused.

  progressDeadlineSeconds       <integer>
    The maximum time in seconds for a deployment to make progress before it is
    considered to be failed. The deployment controller will continue to process
    failed deployments and a condition with a ProgressDeadlineExceeded reason
    will be surfaced in the deployment status. Note that progress will not be
    estimated during the time a deployment is paused. Defaults to 600s.

  replicas      <integer>
    Number of desired pods. This is a pointer to distinguish between explicit
    zero and not specified. Defaults to 1.

  revisionHistoryLimit  <integer>
    The number of old ReplicaSets to retain to allow rollback. This is a pointer
    to distinguish between explicit zero and not specified. Defaults to 10.

  selector      <LabelSelector> -required-
    Label selector for pods. Existing ReplicaSets whose pods are selected by
    this will be the ones affected by this deployment. It must match the pod
    template's labels.

  strategy      <DeploymentStrategy>
    The deployment strategy to use to replace existing pods with new ones.

  template      <PodTemplateSpec> -required-
    Template describes the pods that will be created. The only allowed
    template.spec.restartPolicy value is "Always".
```

#### kubectl describe
`kubectl describe`查看详细信息

```
kubectl describe pod pod-demo-1

Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  30s                default-scheduler  Successfully assigned default/pod-demo-1 to k8s-node-1
  Normal   Pulled     30s                kubelet            Container image "wangyanglinux/myapp:v1.0" already present on machine
  Normal   Created    30s                kubelet            Created container: myapp-1
  Normal   Started    30s                kubelet            Started container myapp-1
  Normal   Pulling    30s                kubelet            Pulling image "wangyanglinux/myapp:v2.0"
  Normal   Pulled     23s                kubelet            Successfully pulled image "wangyanglinux/myapp:v2.0" in 7.475s (7.475s including waiting). Image size: 13542987 bytes.
  Normal   Started    19s (x2 over 23s)  kubelet            Started container myapp-2
  Warning  BackOff    16s                kubelet            Back-off restarting failed container myapp-2 in pod pod-demo-1_default(4bff1673-b1d4-4032-864d-1c6efb24a942)
  Normal   Created    1s (x3 over 23s)   kubelet            Created container: myapp-2
  Normal   Pulled     1s (x2 over 19s)   kubelet            Container image "wangyanglinux/myapp:v2.0" already present on machine
```
> 如果没有得到有用的信息可以使用`kubectl logs`查看容器的日志,如果没有日志则大概率是镜像有问题
#### kubectl logs
查看容器内部的日志
`kubectl logs <pod-nam> -c <containerd-name>`
```
$ kubectl logs pod-demo myapp-1
10.0.0.11 - - [17/Apr/2026:12:42:21 +0800] "GET / HTTP/1.1" 200 48 "-" "curl/7.81.0"
10.0.0.11 - - [17/Apr/2026:12:42:22 +0800] "GET / HTTP/1.1" 200 48 "-" "curl/7.81.0"
10.0.0.11 - - [17/Apr/2026:12:42:23 +0800] "GET / HTTP/1.1" 200 48 "-" "curl/7.81.0"
```

#### kubectl delete
`kubectl delete`删除资源

```
kubectl delete pod podname

# 删除所有pod
kubectl delete pod --all
```
#### kubectl label
`kubectl label`修改标签

```
kubectl label pod rc-demo-l2fpz version=v1

# 查看pod的标签
kubectl get pod --show-labels

# 修改已经存在的标签需要添加--overwrite参数
kubectl label pod rc-demo-thqm6 app=demo --overwrite
```
#### kubectl patch
`kubectl patch`对资源对象打补丁

```
kubectl patch deployment myapp-deploy -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}}}'
```
#### kubectl edit
`kubectl edit`编辑etcd中存储的对象配置

```
# 这会打开默认的编辑器编辑一个资源清单
kubectl edit deployment myapp

# 如果修改后的格式存在错误,将会禁止退出编辑器,再次退出后会将错误的配置文件保存到一个yaml文件中
[root@k8s-master01 ~]# kubectl edit deployment myapp
error: deployments.apps "myapp" is invalid
A copy of your changes has been stored to "/tmp/kubectl-edit-3332387646.yaml"
error: Edit cancelled, no valid changes were saved.
```
#### kubectl scale
`kubectl scale`动态调整由控制器管理的pod副本数量

```
# 修改rs的副本数量
kubectl scale rs rc-demo --replicas=5

# 查看rs类型的资源
kubectl get rs -A
```
#### kubectl autoscale
`kubectl autoscale`自动调整pod副本数量

```
# 当cpu负载低于80%时副本数量设定为10,当负载大于80%时提高副本数量最高达到15
kubectl autoscale deployment deployment-1 --min=10 --max=15 --cpu-percent=80
```
#### kubectl create
`kubectl create`创建资源对象,使用`-f`基于文件的创建,但如果此文件描述的对象存在,那么不会覆盖文件

```
kubectl create -f deployment.yaml

# --record参数可以查看每次revision的变化
```
#### kubectl replace
`kubectl replace -f`使用新的配置完全替换掉现有资源的配置,新配置将**覆盖现有资源的所有字段和属性**,包括未指定的字段

```
kubectl replace -f deployment.yaml 
```
#### kubectl apply
`kubectl apply -f`使用新的配置部分地更新现有资源的配置,它会根据提供的配置文件或参数只更新和新配置中不同的部分,**保留未指定的字段**

```
kubectl apply -f deployment.yaml 
```
#### kubectl diff
`kubectl diff -f`使用指定资源清单与当前资源进行对比

```
kubectl diff -f deployment.yaml 
```
