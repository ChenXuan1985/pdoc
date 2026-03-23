# pdoc Dockerfile

FROM python:3.11-slim-bookworm

LABEL maintainer="pdoc maintainers"
LABEL description="pdoc - Python API documentation generator"

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY setup.py setup.cfg README.md CHANGELOG LICENSE.txt ./
COPY pdoc/ ./pdoc/
COPY doc/ ./doc/

RUN pip install --no-cache-dir -e . && \
    pip cache purge

ENV DOC_PORT=8080

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

ENTRYPOINT ["pdoc"]
CMD ["--http", ":8080", "pdoc"]
