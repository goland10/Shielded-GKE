# 1. THE DEPLOYMENT: The "web" app
resource "kubernetes_deployment_v1" "web" {
  metadata {
    name = "web"
    labels = {
      app = "web"
    }
  }

  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "web"
      }
    }
    template {
      metadata {
        labels = {
          app = "web"
        }
      }
      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# 2. THE SERVICE: Expose the app
resource "kubernetes_service_v1" "web_service" {
  metadata {
    name = "web-service"
  }
  spec {
    selector = {
      app = "web"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

# 3. THE INGRESS: Routing logic
resource "kubernetes_ingress_v1" "web_ingress" {
  metadata {
    name = "web-ingress"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.web_service.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
