package generate_constraints

N = 100

output := {
    "constraints": {
        "K8sAllowedRepos": {
            name: object |
                n := numbers.range(1, N)[_]
                name := sprintf(name_template, [n])
                object := object_template(n)
        }
    }
}

name_template = "prod-repo-is-openpolicyagent-%03d"

object_template(n) = {
    "apiVersion": "constraints.gatekeeper.sh/v1beta1",
    "kind": "K8sAllowedRepos",
    "metadata": {
        "name": sprintf("prod-repo-is-openpolicyagent-%03d", [n])
    },
    "spec": {
        "match": {
            "kinds": [
                {
                    "apiGroups": [
                        ""
                    ],
                    "kinds": [
                        "Pod"
                    ]
                }
            ],
            "namespaces": [
                "production"
            ]
        },
        "parameters": {
            "repos": [
                "only-this-repo"
            ]
        }
    }
}