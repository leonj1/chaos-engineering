# S3 bucket for nginx-hello-world static website
resource "aws_s3_bucket" "nginx_hello_world" {
  bucket = "nginx-hello-world"
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "nginx_hello_world" {
  bucket = aws_s3_bucket.nginx_hello_world.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 bucket policy for public read
resource "aws_s3_bucket_policy" "nginx_hello_world" {
  bucket = aws_s3_bucket.nginx_hello_world.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.nginx_hello_world.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.nginx_hello_world]
}

# S3 bucket website configuration
resource "aws_s3_bucket_website_configuration" "nginx_hello_world" {
  bucket = aws_s3_bucket.nginx_hello_world.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Upload index.html
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.nginx_hello_world.id
  key          = "index.html"
  content_type = "text/html"
  content      = <<-EOT
    <!DOCTYPE html>
    <html>
    <head>
        <title>Hello from Nginx on LocalStack</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
                background-color: #f0f0f0;
            }
            .container {
                text-align: center;
                padding: 50px;
                background-color: white;
                border-radius: 10px;
                box-shadow: 0 0 20px rgba(0,0,0,0.1);
            }
            h1 {
                color: #333;
            }
            .info {
                margin: 20px 0;
                color: #666;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Hello World from Nginx!</h1>
            <div class="info">
                <p>Running on LocalStack S3 Static Website</p>
                <p>Chaos Engineering Demo</p>
                <p>Timestamp: ${timestamp()}</p>
            </div>
        </div>
    </body>
    </html>
  EOT
}

# Upload error.html
resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.nginx_hello_world.id
  key          = "error.html"
  content_type = "text/html"
  content      = <<-EOT
    <!DOCTYPE html>
    <html>
    <head>
        <title>Error - Nginx on LocalStack</title>
    </head>
    <body>
        <h1>Error</h1>
        <p>The requested page was not found.</p>
    </body>
    </html>
  EOT
}

# Output the website endpoint
output "s3_website_endpoint" {
  description = "S3 website endpoint"
  value       = "http://${aws_s3_bucket.nginx_hello_world.id}.s3-website.localhost:4566"
}