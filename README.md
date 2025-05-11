# K8S-Final-project

PROJET DEVOPS - Orchestration Kubernetes : IC GROUP

Introduction

La société IC GROUP souhaite mettre en place une plateforme d'accès à ses deux applications principales :

Odoo 13.0 (édition communautaire avec module LMS)

pgAdmin4 pour l'administration de la base PostgreSQL

Une application web vitrine (développée en Flask) permet d’accéder à ces deux outils via des URL paramétrables par variables d’environnement.

Objectif : Conteneuriser les applications et les déployer dans un cluster Kubernetes (K3S).

Étape I - Conteneurisation de l'application web

1. Création du Dockerfile

# Dockerfile
FROM python:3.6-alpine

WORKDIR /opt

COPY . /opt

RUN pip install flask==1.1.2

ENV ODOO_URL=https://www.odoo.com
ENV PGADMIN_URL=https://www.pgadmin.org

EXPOSE 8080

ENTRYPOINT ["python", "app.py"]



![image](https://github.com/user-attachments/assets/63fa2963-3fcd-4f5f-8609-a49ca2c73500)


2. Fichier requirements.txt

Flask

3. Build de l’image

docker build -t ic-webapp:1.0 .

![image](https://github.com/user-attachments/assets/5c96c8f1-a569-435f-9844-540c80a9038b)

4. Test local avec variables d’environnement

docker run -d --name test-ic-webapp -p 8080:8080 \
  -e ODOO_URL=https://www.odoo.com \
  -e PGADMIN_URL=https://www.pgadmin.org \
  ic-webapp:1.0

![image](https://github.com/user-attachments/assets/a5b57871-7c74-4d9a-9fdf-807d68bde15c)


5. Suppression du container de test

docker rm -f test-ic-webapp

![image](https://github.com/user-attachments/assets/02d8625d-1b42-4e76-85f2-742ad5399926)

6. Push sur Docker Hub

docker tag ic-webapp:1.0 safouane95/ic-webapp:1.0
docker push safouane95/ic-webapp:1.0

![image](https://github.com/user-attachments/assets/2230bfed-7055-4478-8d50-c95118b6166f)


![image](https://github.com/user-attachments/assets/cb75b6aa-360a-46dc-bcba-1cf0fc168b54)


Étape II - Déploiement Kubernetes dans K8S

1. Namespace & Label communs

apiVersion: v1
kind: Namespace
metadata:
  name: icgroup
  labels:
    env: prod

kubectl apply -f namespace.yaml

![image](https://github.com/user-attachments/assets/197e13dd-478a-468b-a2ad-f96fb3ecb804)


Étape III - Déploiement PostgreSQL

1. Déploiement + PVC

apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: icgroup
  labels:
    app: postgres
    env: prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
        env: prod
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_PASSWORD
          value: admin123
        volumeMounts:
        - mountPath: /var/lib/postgresql/data
          name: postgres-pv
      volumes:
      - name: postgres-pv
        persistentVolumeClaim:
          claimName: postgres-pvc

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: icgroup
  labels:
    env: prod
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi

![image](https://github.com/user-attachments/assets/6a984651-8b9b-4268-8356-71c795d3c700)



Étape IV - Déploiement Odoo

apiVersion: apps/v1
kind: Deployment
metadata:
  name: odoo
  namespace: icgroup
  labels:
    app: odoo
    env: prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: odoo
  template:
    metadata:
      labels:
        app: odoo
        env: prod
    spec:
      containers:
      - name: odoo
        image: odoo:13.0
        ports:
        - containerPort: 8069
        env:
        - name: HOST
          value: postgres
        - name: USER
          value: postgres
        - name: PASSWORD
          value: admin123
          
![image](https://github.com/user-attachments/assets/56252ec3-116b-4de2-988b-02bb3ccb26e0)


![image](https://github.com/user-attachments/assets/245599c5-1f9a-42c5-9ee8-6407b3ce871e)


Étape V - Déploiement pgAdmin avec configuration

1. Création d’un ConfigMap avec servers.json

{
  "Servers": {
    "1": {
      "Name": "Postgres Server",
      "Group": "Servers",
      "Host": "postgres",
      "Port": 5432,
      "Username": "postgres",
      "SSLMode": "prefer",
      "MaintenanceDB": "postgres"
    }
  }
}

kubectl create configmap pgadmin-config --from-file=servers.json=servers.json -n icgroup

![image](https://github.com/user-attachments/assets/337c6f47-77f0-4387-acec-ec67652dbe34)


2. Déploiement pgAdmin avec volume

apiVersion: apps/v1
kind: Deployment
metadata:
  name: pgadmin
  namespace: icgroup
  labels:
    app: pgadmin
    env: prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pgadmin
  template:
    metadata:
      labels:
        app: pgadmin
        env: prod
    spec:
      containers:
      - name: pgadmin
        image: dpage/pgadmin4
        env:
        - name: PGADMIN_DEFAULT_EMAIL
          value: admin@icgroup.local
        - name: PGADMIN_DEFAULT_PASSWORD
          value: admin123
        volumeMounts:
        - name: config-volume
          mountPath: /pgadmin4/servers.json
          subPath: servers.json
      volumes:
      - name: config-volume
        configMap:
          name: pgadmin-config

![image](https://github.com/user-attachments/assets/d88fb1f1-8fec-4c44-b854-07c7bf02335f)


Étape VI - Déploiement de l’ic-webapp dans le cluster

apiVersion: apps/v1
kind: Deployment
metadata:
  name: ic-webapp
  namespace: icgroup
  labels:
    app: ic-webapp
    env: prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ic-webapp
  template:
    metadata:
      labels:
        app: ic-webapp
        env: prod
    spec:
      containers:
      - name: ic-webapp
        image: safouane95/ic-webapp:1.0
        ports:
        - containerPort: 8080
        env:
        - name: ODOO_URL
          value: "http://odoo.icgroup.svc.cluster.local:8069"
        - name: PGADMIN_URL
          value: "http://pgadmin.icgroup.svc.cluster.local"

![image](https://github.com/user-attachments/assets/194a4229-06fe-4da3-aed2-6ea008a81f88)





Étape VII - Services & accès

![image](https://github.com/user-attachments/assets/85f28c6a-2872-427a-9604-0f763e237af9)



Étape VIII - Vérifications et conclusion

1. Vérifier les pods et services

kubectl get all -n icgroup

![image](https://github.com/user-attachments/assets/f832bda1-75fe-4980-b6d8-e136e12c9dd3)


![image](https://github.com/user-attachments/assets/ec17b6da-213e-4528-8abf-36679f42ddac)


2. Conclusion

Toutes les applications sont déployées avec persistance des données
Accès web fonctionnel pour Odoo, pgAdmin, site vitrine



Auteur

Nom : CHAABANE SAFOUANE

Étudiant 5SRC2 DevOps

Date : 11/05/2025

