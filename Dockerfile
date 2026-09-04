FROM python:3.13-slim

WORKDIR /app

# DEFECT: the source is copied BEFORE the dependencies are installed.
# Week 3 measured what this costs. Every code edit reinstalls everything.
COPY . .

RUN pip install --no-cache-dir -r api/requirements.txt

EXPOSE 8000
CMD ["flask", "--app", "api/app.py", "run", "--host", "0.0.0.0", "--port", "8000"]
