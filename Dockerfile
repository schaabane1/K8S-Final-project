FROM python:3.6-alpine

WORKDIR /opt

COPY . /opt

RUN pip install flask==1.1.2

ENV ODOO_URL=https://www.odoo.com
ENV PGADMIN_URL=https://www.pgadmin.org

EXPOSE 8080

ENTRYPOINT ["python", "app.py"]
