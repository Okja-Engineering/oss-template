# Setup questionnaire

`bin/ask questionnaire` writes this file from `shared/answers.tsv`, so a change goes in the schema, not here. Answer every question at once, then record the answers with `bin/ask setup FIELD=value…`, which writes `setup/answers.env`. In a default, `{{FIELD}}` stands for that field's answer.

1. Which GitHub account or organization will own the repositories? (`OWNER`, owner; default `Okja-Engineering`)
2. Which directory, outside the workspace, holds the targets? (`TARGET_ROOT`, path; default `~/Development/{{OWNER}}`)
