def call(String buildStatus = 'STARTED') {
    buildStatus = buildStatus ?: 'SUCCESS'

    def color
    def emoji

    if (buildStatus == 'SUCCESS') {
        color = '#47ec05'
        emoji = ':ww:'
    } else if (buildStatus == 'UNSTABLE') {
        color = '#d5ee0d'
        emoji = ':deadpool:'
    } else {
        color = '#ec2805'
        emoji = ':hulk:'
    }

    // Safely retrieve environment variables with fallbacks
    def deploymentName = env.deploymentName ?: 'devsecops'
    def failedStageDisplay = env.failedStage ?: 'N/A'
    def appURL = env.applicationURL ?: 'http://192.168.49.2'
    def gitPreviousCommit = env.GIT_PREVIOUS_SUCCESSFUL_COMMIT ?: 'N/A'
    def gitCommit = env.GIT_COMMIT ?: 'N/A'
    def gitBranch = env.GIT_BRANCH ?: 'N/A'
    def gitUrl = env.GIT_URL ?: ''

    def blocks = [
        [
            "type": "header",
            "text": [
                "type": "plain_text",
                "text": "K8S Deployment - ${deploymentName} Pipeline",
                "emoji": true
            ]
        ],
        [
            "type": "section",
            "fields": [
                [
                    "type": "mrkdwn",
                    "text": "*Job Name:*\n${env.JOB_NAME}"
                ],
                [
                    "type": "mrkdwn",
                    "text": "*Build Number:*\n${env.BUILD_NUMBER}"
                ]
            ],
            "accessory": [
                "type": "image",
                "image_url": "https://raw.githubusercontent.com/sidd-harth/devsecops-k8s-demo/main/slack-emojis/jenkins.png",
                "alt_text": "Slack Icon"
            ]
        ],
        [
            "type": "section",
            "text": [
                "type": "mrkdwn",
                "text": "*Failed Stage Name:* `${failedStageDisplay}`"
            ],
            "accessory": [
                "type": "button",
                "text": [
                    "type": "plain_text",
                    "text": "Jenkins Build URL",
                    "emoji": true
                ],
                "value": "click_me_123",
                "url": "${env.BUILD_URL}",
                "action_id": "button-action"
            ]
        ],
        [
            "type": "divider"
        ],
        [
            "type": "section",
            "fields": [
                [
                    "type": "mrkdwn",
                    "text": "*Kubernetes Deployment Name:*\n${deploymentName}"
                ],
                [
                    "type": "mrkdwn",
                    "text": "*Node Port*\n32564"
                ]
            ],
            "accessory": [
                "type": "image",
                "image_url": "https://raw.githubusercontent.com/sidd-harth/devsecops-k8s-demo/main/slack-emojis/k8s.png",
                "alt_text": "Kubernetes Icon"
            ]
        ],
        [
            "type": "section",
            "text": [
                "type": "mrkdwn",
                "text": "*Kubernetes Node:* `controlplane`"
            ],
            "accessory": [
                "type": "button",
                "text": [
                    "type": "plain_text",
                    "text": "Application URL",
                    "emoji": true
                ],
                "value": "click_me_123",
                "url": "${appURL}:32564",
                "action_id": "button-action"
            ]
        ],
        [
            "type": "divider"
        ],
        [
            "type": "section",
            "fields": [
                [
                    "type": "mrkdwn",
                    "text": "*Git Commit:*\n${gitCommit}"
                ],
                [
                    "type": "mrkdwn",
                    "text": "*GIT Previous Success Commit:*\n${gitPreviousCommit}"
                ]
            ],
            "accessory": [
                "type": "image",
                "image_url": "https://raw.githubusercontent.com/sidd-harth/devsecops-k8s-demo/main/slack-emojis/github.png",
                "alt_text": "Github Icon"
            ]
        ],
        [
            "type": "section",
            "text": [
                "type": "mrkdwn",
                "text": "*Git Branch:* `${gitBranch}`"
            ],
            "accessory": [
                "type": "button",
                "text": [
                    "type": "plain_text",
                    "text": "Github Repo URL",
                    "emoji": true
                ],
                "value": "click_me_123",
                "url": "${gitUrl}",
                "action_id": "button-action"
            ]
        ]
    ]

    // Fallback message text for standard notifications
    def summaryMessage = "*${buildStatus}*: Job `${env.JOB_NAME}` #${env.BUILD_NUMBER}"

    slackSend(
        color: color,
        iconEmoji: emoji,
        message: summaryMessage,
        blocks: blocks
    )
}