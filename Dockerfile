FROM nimlang/nim:alpine as builder

COPY . /build
WORKDIR /build

RUN nim c -d:release --passL:-static norbert.nim

FROM scratch

COPY --from=builder /build/norbert /norbert
ENTRYPOINT ["/norbert"]