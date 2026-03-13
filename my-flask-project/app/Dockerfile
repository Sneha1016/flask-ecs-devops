FROM python:3.11-slim
WORKDIR /app
# Copy and install dependencies first (Docker layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# Copy application code
COPY . .
ENV PYTHONUNBUFFERED=1
ENV PORT=5000
EXPOSE 5000
# -w 2 = 2 gunicorn worker processes
# -b 0.0.0.0:5000 = MUST bind all interfaces (not 127.0.0.1)
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5000", "wsgi:app"]