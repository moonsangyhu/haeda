# Stage 1: Build Flutter web
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . .

RUN flutter pub get
RUN dart run build_runner build --delete-conflicting-outputs
RUN flutter build web --no-tree-shake-icons

# Stage 2: Serve with nginx
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
