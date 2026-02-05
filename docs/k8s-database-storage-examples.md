# Kubernetes Database Storage Examples - TrueNAS democratic-csi

Examples of deploying databases using iSCSI (block) and NFS (file) storage from TrueNAS.

## Storage Classes

First, ensure democratic-csi storage classes are configured:

```yaml
---
# iSCSI Block Storage (fast pool, RAIDZ2)
# Best for: PostgreSQL, MySQL, Redis, ClickHouse
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: truenas-iscsi-fast
provisioner: org.democratic-csi.iscsi-fast
parameters:
  fsType: ext4
  detachedVolumesFromSnapshots: "true"
  detachedVolumesFromVolumes: "true"
volumeBindingMode: Immediate
allowVolumeExpansion: true
reclaimPolicy: Retain

---
# NFS File Storage (fast pool, RAIDZ2)
# Best for: Shared configs, small app data
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: truenas-nfs-fast
provisioner: org.democratic-csi.nfs-fast
parameters:
  detachedVolumesFromSnapshots: "true"
volumeBindingMode: Immediate
allowVolumeExpansion: true
reclaimPolicy: Retain

---
# NFS File Storage (bulk pool, RAIDZ2)
# Best for: Large app data, Forgejo registry
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: truenas-nfs-bulk
provisioner: org.democratic-csi.nfs-bulk
parameters:
  detachedVolumesFromSnapshots: "true"
volumeBindingMode: Immediate
allowVolumeExpansion: true
reclaimPolicy: Retain
```

## Example 1: PostgreSQL with iSCSI Block Storage (Recommended)

**Why iSCSI**: Better IOPS, lower latency, direct block access, ideal for transactional databases.

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: databases

---
# PVC for PostgreSQL data
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: databases
  labels:
    app: postgres
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: truenas-iscsi-fast
  resources:
    requests:
      storage: 50Gi

---
# Secret for PostgreSQL credentials
apiVersion: v1
kind: Secret
metadata:
  name: postgres-credentials
  namespace: databases
type: Opaque
stringData:
  POSTGRES_USER: appuser
  POSTGRES_PASSWORD: changeme-use-1password
  POSTGRES_DB: appdb

---
# PostgreSQL StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: databases
  labels:
    app: postgres
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
          name: postgres
        envFrom:
        - secretRef:
            name: postgres-credentials
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
          subPath: pgdata
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
      volumes:
      - name: postgres-data
        persistentVolumeClaim:
          claimName: postgres-data

---
# PostgreSQL Service
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: databases
  labels:
    app: postgres
spec:
  type: ClusterIP
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
    name: postgres
  selector:
    app: postgres
```

## Example 2: MySQL with iSCSI Block Storage

```yaml
---
# PVC for MySQL data
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-data
  namespace: databases
  labels:
    app: mysql
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: truenas-iscsi-fast
  resources:
    requests:
      storage: 30Gi

---
# Secret for MySQL credentials
apiVersion: v1
kind: Secret
metadata:
  name: mysql-credentials
  namespace: databases
type: Opaque
stringData:
  MYSQL_ROOT_PASSWORD: changeme-use-1password
  MYSQL_DATABASE: appdb
  MYSQL_USER: appuser
  MYSQL_PASSWORD: changeme-use-1password

---
# MySQL StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  namespace: databases
  labels:
    app: mysql
spec:
  serviceName: mysql
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.3
        ports:
        - containerPort: 3306
          name: mysql
        envFrom:
        - secretRef:
            name: mysql-credentials
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
        livenessProbe:
          exec:
            command:
            - mysqladmin
            - ping
            - -h
            - localhost
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - mysql
            - -h
            - localhost
            - -u
            - root
            - -p$MYSQL_ROOT_PASSWORD
            - -e
            - SELECT 1
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
      volumes:
      - name: mysql-data
        persistentVolumeClaim:
          claimName: mysql-data

---
# MySQL Service
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: databases
  labels:
    app: mysql
spec:
  type: ClusterIP
  ports:
  - port: 3306
    targetPort: 3306
    protocol: TCP
    name: mysql
  selector:
    app: mysql
```

## Example 3: Redis with iSCSI Block Storage

```yaml
---
# PVC for Redis data
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data
  namespace: databases
  labels:
    app: redis
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: truenas-iscsi-fast
  resources:
    requests:
      storage: 10Gi

---
# Redis ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: databases
data:
  redis.conf: |
    # Redis persistence configuration
    appendonly yes
    appendfsync everysec
    save 900 1
    save 300 10
    save 60 10000

    # Memory management
    maxmemory 1gb
    maxmemory-policy allkeys-lru

    # Security
    protected-mode yes
    requirepass changeme-use-1password

---
# Redis StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: databases
  labels:
    app: redis
spec:
  serviceName: redis
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        command:
        - redis-server
        - /usr/local/etc/redis/redis.conf
        ports:
        - containerPort: 6379
          name: redis
        volumeMounts:
        - name: redis-data
          mountPath: /data
        - name: redis-config
          mountPath: /usr/local/etc/redis
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 20
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
      volumes:
      - name: redis-data
        persistentVolumeClaim:
          claimName: redis-data
      - name: redis-config
        configMap:
          name: redis-config

---
# Redis Service
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: databases
  labels:
    app: redis
spec:
  type: ClusterIP
  ports:
  - port: 6379
    targetPort: 6379
    protocol: TCP
    name: redis
  selector:
    app: redis
```

## Example 4: ClickHouse with iSCSI Block Storage (Signoz)

```yaml
---
# PVC for ClickHouse data
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: clickhouse-data
  namespace: observability
  labels:
    app: clickhouse
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: truenas-iscsi-fast
  resources:
    requests:
      storage: 100Gi

---
# ClickHouse StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: clickhouse
  namespace: observability
  labels:
    app: clickhouse
spec:
  serviceName: clickhouse
  replicas: 1
  selector:
    matchLabels:
      app: clickhouse
  template:
    metadata:
      labels:
        app: clickhouse
    spec:
      containers:
      - name: clickhouse
        image: clickhouse/clickhouse-server:24.1-alpine
        ports:
        - containerPort: 8123
          name: http
        - containerPort: 9000
          name: native
        volumeMounts:
        - name: clickhouse-data
          mountPath: /var/lib/clickhouse
        env:
        - name: CLICKHOUSE_DB
          value: "signoz"
        - name: CLICKHOUSE_USER
          value: "signoz"
        - name: CLICKHOUSE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: clickhouse-credentials
              key: password
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "8Gi"
            cpu: "4000m"
        livenessProbe:
          httpGet:
            path: /ping
            port: 8123
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ping
            port: 8123
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
      volumes:
      - name: clickhouse-data
        persistentVolumeClaim:
          claimName: clickhouse-data

---
# ClickHouse Service
apiVersion: v1
kind: Service
metadata:
  name: clickhouse
  namespace: observability
  labels:
    app: clickhouse
spec:
  type: ClusterIP
  ports:
  - port: 8123
    targetPort: 8123
    protocol: TCP
    name: http
  - port: 9000
    targetPort: 9000
    protocol: TCP
    name: native
  selector:
    app: clickhouse
```

## Example 5: Forgejo with NFS for Large Registry

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: forgejo

---
# PVC for Forgejo data (configs, git repos)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: forgejo-data
  namespace: forgejo
  labels:
    app: forgejo
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: truenas-nfs-fast
  resources:
    requests:
      storage: 10Gi

---
# PVC for Forgejo registry (large container images)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: forgejo-registry
  namespace: forgejo
  labels:
    app: forgejo
    component: registry
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: truenas-nfs-bulk
  resources:
    requests:
      storage: 500Gi

---
# Forgejo Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: forgejo
  namespace: forgejo
  labels:
    app: forgejo
spec:
  replicas: 1
  strategy:
    type: Recreate  # Single replica with RWO volumes
  selector:
    matchLabels:
      app: forgejo
  template:
    metadata:
      labels:
        app: forgejo
    spec:
      containers:
      - name: forgejo
        image: codeberg.org/forgejo/forgejo:1.21
        ports:
        - containerPort: 3000
          name: http
        - containerPort: 22
          name: ssh
        volumeMounts:
        - name: forgejo-data
          mountPath: /data
        - name: forgejo-registry
          mountPath: /data/forgejo-registry
        env:
        - name: USER_UID
          value: "1000"
        - name: USER_GID
          value: "1000"
        - name: FORGEJO__database__DB_TYPE
          value: "postgres"
        - name: FORGEJO__database__HOST
          value: "postgres.databases.svc.cluster.local:5432"
        - name: FORGEJO__database__NAME
          value: "forgejo"
        - name: FORGEJO__database__USER
          valueFrom:
            secretKeyRef:
              name: forgejo-db-credentials
              key: username
        - name: FORGEJO__database__PASSWD
          valueFrom:
            secretKeyRef:
              name: forgejo-db-credentials
              key: password
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /api/healthz
            port: 3000
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /api/healthz
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
      volumes:
      - name: forgejo-data
        persistentVolumeClaim:
          claimName: forgejo-data
      - name: forgejo-registry
        persistentVolumeClaim:
          claimName: forgejo-registry

---
# Forgejo Service
apiVersion: v1
kind: Service
metadata:
  name: forgejo
  namespace: forgejo
  labels:
    app: forgejo
spec:
  type: ClusterIP
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
    name: http
  - port: 22
    targetPort: 22
    protocol: TCP
    name: ssh
  selector:
    app: forgejo
```

## Storage Decision Matrix

| Database/App | Storage Type | Storage Class | Pool | Why |
|--------------|--------------|---------------|------|-----|
| PostgreSQL | iSCSI | `truenas-iscsi-fast` | fast | Transactional DB, needs low latency |
| MySQL | iSCSI | `truenas-iscsi-fast` | fast | Transactional DB, needs low latency |
| Redis | iSCSI | `truenas-iscsi-fast` | fast | In-memory + persistence, needs fast I/O |
| ClickHouse | iSCSI | `truenas-iscsi-fast` | fast | Time-series DB, needs fast sequential writes |
| Forgejo data | NFS | `truenas-nfs-fast` | fast | Git repos, configs (small, frequently accessed) |
| Forgejo registry | NFS | `truenas-nfs-bulk` | bulk | Container images (large, read-heavy) |
| Jellyfin media | NFS | Static PV | bulk | Large sequential reads, read-only |
| CI cache | NFS | `truenas-nfs-scratch` | scratch | Ephemeral, can rebuild |

## Key Points

### When to Use iSCSI Block Storage
- ✅ Transactional databases (PostgreSQL, MySQL, MariaDB)
- ✅ Time-series databases (ClickHouse, InfluxDB, Prometheus)
- ✅ Key-value stores with persistence (Redis, etcd)
- ✅ When you need direct block access and low latency
- ✅ Single-pod workloads (ReadWriteOnce)

### When to Use NFS File Storage
- ✅ Shared configuration files (ReadWriteMany)
- ✅ Large files (media, backups, archives)
- ✅ Container registries (Forgejo, Harbor)
- ✅ Static content (websites, documentation)
- ✅ Multi-pod workloads needing shared access

### Best Practices

1. **Always use StatefulSets for databases** (not Deployments)
   - Stable network identity
   - Ordered deployment/scaling
   - Persistent storage guarantees

2. **Set resource requests and limits**
   - Prevents resource starvation
   - Helps scheduler make decisions
   - Enables horizontal pod autoscaling

3. **Configure probes correctly**
   - Liveness: Restart unhealthy pods
   - Readiness: Remove from service endpoints
   - Use appropriate timeouts and thresholds

4. **Use secrets for credentials**
   - Never hardcode passwords
   - Consider 1Password integration or external-secrets-operator

5. **Enable PVC expansion**
   - All storage classes have `allowVolumeExpansion: true`
   - Can grow volumes without downtime: `kubectl patch pvc postgres-data -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'`

## Deployment Commands

```bash
# Create namespace
kubectl create namespace databases

# Apply storage classes (if not already deployed)
kubectl apply -f storage-classes.yaml

# Deploy PostgreSQL
kubectl apply -f postgres.yaml

# Verify deployment
kubectl get pods -n databases
kubectl get pvc -n databases
kubectl get svc -n databases

# Check logs
kubectl logs -n databases postgres-0 -f

# Connect to database
kubectl exec -it -n databases postgres-0 -- psql -U appuser -d appdb

# Check PVC usage
kubectl exec -n databases postgres-0 -- df -h /var/lib/postgresql/data

# Expand PVC if needed (50Gi → 100Gi)
kubectl patch pvc postgres-data -n databases -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
```

## Monitoring Storage Usage

```bash
# Check all PVCs
kubectl get pvc -A

# Detailed PVC info
kubectl describe pvc postgres-data -n databases

# Check iSCSI zvol usage on TrueNAS
ssh admin@192.168.0.13 "zfs list -r fast/kubernetes/iscsi-zvols"

# Check NFS dataset usage on TrueNAS
ssh admin@192.168.0.13 "zfs list -r fast/kubernetes/nfs-dynamic"
```
