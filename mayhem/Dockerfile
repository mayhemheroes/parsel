# Build Stage
FROM python:3.11-slim

# Install atheris build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    clang \
    python3-dev \
    libfuzzer-17-dev \
    && rm -rf /var/lib/apt/lists/*

# Install atheris
RUN pip install --no-cache-dir atheris

ADD . /src
WORKDIR /src
RUN pip install --no-cache-dir .

CMD ["/src/mayhem/fuzz_extract.py"]
