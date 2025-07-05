FROM golang:alpine AS builder
RUN go install github.com/kylegrantlucas/pia-wg-config@latest

FROM alpine:latest
RUN apk --no-cache add ca-certificates wireguard-tools
COPY --from=builder /go/bin/pia-wg-config /usr/local/bin/
ENTRYPOINT ["pia-wg-config"]