FROM golang:1.25.1 AS builder

WORKDIR /app

RUN apt install ca-certificates
COPY trusted_certs.pem /etc/ssl/certs/trusted_certs.pem

COPY go.mod .
COPY go.sum .
RUN go mod download

COPY main.go .

RUN go build -o webhook main.go

FROM gcr.io/distroless/base
COPY --from=builder /app/webhook /webhook

ENTRYPOINT [ "/webhook" ]