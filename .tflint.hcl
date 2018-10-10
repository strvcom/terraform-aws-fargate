config {
  deep_check = true

  # We need to ignore the module checking because TFLint currently does not support TF v0.11 module resolver 😕
  # https://github.com/wata727/tflint/issues/167
  ignore_module = {
    "terraform-aws-modules/vpc/aws" = true
  }
}
