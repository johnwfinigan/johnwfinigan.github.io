title: Trouble Enabling Vertex AI With Terraform
date: 2025-05-07
css: style.css
tags: gcp


## Trouble Enabling Vertex AI With Terraform

Since at least 2023 some of my older Terraform code bases for Google Cloud would fail when trying to enable the Vertex AI (aiplatform.googleapis.com) or Vertex AI Workbench (notebooks.googleapis.com) APIs on a project. The projects were created with the Google Project Factory Terraform module, but I suspect that the problem is not inherent to that module. Enabling the API by hand would succeed, so while this was annoying, that is how I would work around it. After a one time manual API enablement, the Terraform code would apply cleanly.

The error code, ```SERVICE_CONFIG_NOT_FOUND_OR_PERMISSION_DENIED```, seemed like it would be a good lead, but didn't lead to many search engine hits. There were some suggestions that the identity Terraform was running as needed to have Service Usage Admin on the project, and while that may be needed, it was not a fix in my case.

After many failed attempts to identify the cause, the solution was to update all of the Google Terraform modules involved in the apply. I don't think any given module's implementation was the problem. Each module sets constraints on what versions of the Google terraform provider it will accept. Terraform calculates a lowest common denominator and does the apply using that version of the provider. Here, one of the modules was apparently constraining it to use a version of the provider that was too old to handle these APIs. I don't use many 3rd party modules, and this part of the code was in need of maintenance, so I ended up updating all of them to the latest after testing. This was part of an effort to pin module versions by Git hash, as an unrelated security improvement, and so it was a good time to do it. 

In short, find the modules you have in your Terraform code which use the Google provider, and update them if they are old. Provider version constraints in the old modules may be causing your API enablement to fail.

Example error:

```
[
  {
    "@type": "type.googleapis.com/google.rpc.PreconditionFailure",
    "violations": [
      {
        "subject": "?error_code=220002\u0026services=aiplatform.googeapis.com",
        "type": "googleapis.com"
      }
    ]
  },
  {
    "@type": "type.googleapis.com/google.rpc.ErrorInfo",
    "domain": "serviceusage.googleapis.com",
    "metadata": {
      "services": "aiplatform.googeapis.com"
    },
    "reason": "SERVICE_CONFIG_NOT_FOUND_OR_PERMISSION_DENIED"
  }
]
, forbidden
```
