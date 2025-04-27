# 🧭 Ethics Tag: v0.1

This project includes an ethics layer that acts as a guardrail against misuse.

### ❌ Prohibited Workflows

Planners must not generate workflows that include:

- Harm to humans (e.g. torture, assassination)
- Exploitation of children (e.g. trafficking, abuse)
- Criminal activity (e.g. hacking, theft, fraud)

If a submitted goal appears to violate these principles, the system will return:

```json
{ "error": "Unethical violation", "code": 666 }
