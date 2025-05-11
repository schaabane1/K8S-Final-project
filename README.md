# K8S-Final-project

PROJET DEVOPS - Orchestration Kubernetes : IC GROUP

Introduction

La société IC GROUP souhaite mettre en place une plateforme d'accès à ses deux applications principales :

Odoo 13.0 (édition communautaire avec module LMS)

pgAdmin4 pour l'administration de la base PostgreSQL

Une application web vitrine (développée en Flask) permet d’accéder à ces deux outils via des URL paramétrables par variables d’environnement.

Objectif : Conteneuriser les applications et les déployer dans un cluster Kubernetes (Minikube).

Étape I - Conteneurisation de l'application web

1. Création du Dockerfile

# Dockerfile
FROM python:3.6-alpine
WORKDIR /opt
COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8080
ENV ODOO_URL="http://odoo.default.svc.cluster.local"
ENV PGADMIN_URL="http://pgadmin.default.svc.cluster.local"
ENTRYPOINT ["python", "app.py"]

![image](https://github.com/user-attachments/assets/5c96c8f1-a569-435f-9844-540c80a9038b)


2. Fichier requirements.txt

Flask

3. Build de l’image

docker build -t ic-webapp:1.0 .

4. Test local avec variables d’environnement

docker run -d --name test-ic-webapp -p 8080:8080 \
  -e ODOO_URL=https://www.odoo.com \
  -e PGADMIN_URL=https://www.pgadmin.org \
  ic-webapp:1.0

👉 Capture à insérer ici : affichage site vitrine avec liens vers Odoo et pgAdmin officiels

5. Suppression du container de test

docker rm -f test-ic-webapp

6. Push sur Docker Hub

docker tag ic-webapp:1.0 <votre_dockerhub>/ic-webapp:1.0
docker push <votre_dockerhub>/ic-webapp:1.0

Étape II - Déploiement Kubernetes dans Minikube

1. Namespace & Label communs

apiVersion: v1
kind: Namespace
metadata:
  name: icgroup
  labels:
    env: prod

kubectl apply -f namespace.yaml

👉 Capture à insérer ici : kubectl get ns --show-labels

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

👉 Capture : kubectl get pods,pvc -n icgroup

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

👉 Capture : kubectl get svc -n icgroup pour Odoo

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

👉 Capture : pgAdmin montre déjà le serveur configuré

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
        image: <votre_dockerhub>/ic-webapp:1.0
        ports:
        - containerPort: 8080
        env:
        - name: ODOO_URL
          value: "http://odoo.icgroup.svc.cluster.local:8069"
        - name: PGADMIN_URL
          value: "http://pgadmin.icgroup.svc.cluster.local"

👉 Capture : affichage de la page vitrine avec accès à Odoo & pgAdmin depuis le cluster

Étape VII - Services & accès

apiVersion: v1
kind: Service
metadata:
  name: odoo
  namespace: icgroup
  labels:
    app: odoo
    env: prod
spec:
  selector:
    app: odoo
  ports:
  - port: 8069
    targetPort: 8069
    protocol: TCP
  type: NodePort

Faire de même pour pgadmin et ic-webapp avec type: NodePort

👉 Capture : accès aux applications via NodePort sur Minikube IP

Étape VIII - Vérifications et conclusion

1. Vérifier les pods et services

kubectl get all -n icgroup

👉 Capture : tous les pods et services UP

2. Conclusion

Toutes les applications sont déployées avec persistance des données

Accès web fonctionnel pour Odoo, pgAdmin, site vitrine

Variables sensibles isolées ou configurées en ConfigMap

Améliorations possibles

Intégration TLS (cert-manager + Ingress)

CI/CD avec GitHub Actions ou GitLab

Utilisation de Secrets pour les mots de passe sensibles

Monitoring via Prometheus/Grafana

Auteur

Nom : [Votre Nom]

Étudiant 5ESGI DevOps

Date : [à compléter]

