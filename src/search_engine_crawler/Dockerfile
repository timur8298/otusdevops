FROM python:3.6-alpine

COPY . /

RUN pip install -r requirements.txt -r requirements-test.txt

ENV MONGO crawler_db
ENV MONGO_PORT 27017
ENV RMQ_HOST rabbitmq
ENV RMQ_QUEUE search-engine
ENV RMQ_USERNAME rabbituser
ENV RMQ_PASSWORD rabbitpass
ENV CHECK_INTERVAL 30
ENV EXCLUDE_URLS '.*github.com'
ENV START_URL 'https://vitkhab.github.io/search_engine_test_site/'

CMD python -u crawler/crawler.py $START_URL
