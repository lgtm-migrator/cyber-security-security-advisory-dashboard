resource "aws_codepipeline" "cd-security-advisory-dashboard" {
  name     = var.pipeline_name
  role_arn = data.aws_iam_role.pipeline_role.arn
  tags     = merge(local.tags, { Name = var.pipeline_name })

  artifact_store {
    type     = "S3"
    location = data.aws_s3_bucket.artifact_store.bucket
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["git_security_advisory_dashboard"]
      configuration = {
        ConnectionArn    = "arn:aws:codestar-connections:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:connection/${var.codestar_connection_id}"
        FullRepositoryId = var.repository_name
        BranchName       = var.github_branch_name
      }
    }
  }

  stage {
    name = "Prep"

    action {
      name             = "GetChangedFiles"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      run_order        = 1
      input_artifacts  = ["git_security_advisory_dashboard"]
      output_artifacts = ["changed_files"]
      configuration = {
        ProjectName = module.codebuild_get_changed_file_list.project_name
      }
    }

    action {
      name             = "GetActionsRequired"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      run_order        = 2
      input_artifacts  = ["git_security_advisory_dashboard", "changed_files"]
      output_artifacts = ["actions_required"]
      configuration = {
        PrimarySource = "git_security_advisory_dashboard"
        ProjectName   = module.codebuild_get_actions_required.project_name
      }
    }
  }

stage {
    name = "Tests"

    action {
      name             = "SecAdvisoryTests"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      run_order        = 1
      input_artifacts  = ["git_security_advisory_dashboard", "changed_files"]
      configuration = {
        PrimarySource = "git_security_advisory_dashboard"
        ProjectName   = aws_codebuild_project.codebuild_build_sec_adv_tests.name
      }
    }
  }

  stage {
    name = "Tests"

    action {
      name             = "SecAdvisoryContractTests"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      run_order        = 1
      input_artifacts  = ["git_security_advisory_dashboard", "changed_files"]
      configuration = {
        PrimarySource = "git_security_advisory_dashboard"
        ProjectName   = aws_codebuild_project.codebuild_build_github_contract_tests.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name      = "TerraformApply"
      category  = "Build"
      owner     = "AWS"
      provider  = "CodeBuild"
      version   = "1"
      run_order = 1
      input_artifacts = ["git_security_advisory_dashboard"]
      output_artifacts = [
        "staging_terraform_output"
      ]

      configuration = {
        PrimarySource = "git_security_advisory_dashboard"
        ProjectName   = module.codebuild_terraform_deploy.project_name
      }
    }
  }

  #stage {
  #  name = "Pipeline"

  #  action {
  #    name             = "UpdatePipeline"
  #    category         = "Build"
  #    owner            = "AWS"
  #    provider         = "CodeBuild"
  #    version          = "1"
  #    run_order        = 1
  #    input_artifacts  = ["git_security_advisory_dashboard"]
  #    output_artifacts = []

  #    configuration = {
  #      ProjectName = module.codebuild_self_update.project_name
  #    }
  #  }
  #}
}