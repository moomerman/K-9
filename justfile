build-release:
    mkdir -p bin
    odin build . -o:aggressive -out:bin/K-9{{ if os_family() == "windows" { ".exe" } else { "" } }}

build-web:
    odin run .deps/github.com/karl-zylinski/karl2d/build_web -- . -o:size
    rm -r build

serve-web: build-web
    echo "-> http://localhost:8080"
    python3 -m http.server 8080 -b localhost -d bin/web

check:
    odin check . -vet -strict-style -vet-semicolon -vet-cast -vet-using-param -vet-shadowing -vet-packages:main,game -warnings-as-errors

format:
    odinfmt -w .

verify: format check build-release build-web
