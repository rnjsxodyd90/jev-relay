# Blinded quality rubric

Both raters see only source, context, example gold/reference requirements and anonymized outputs. They do not see model/arm labels, timings or costs. Output order alternates independently by case.

Each output is scored separately on: (1) actionCorrect, (2) meaning preservation, (3) context/register/requirement compliance, (4) natural Dutch. The pre-specified primary success is actionCorrect AND meaning AND context. Naturalness is reported separately. Exact reference matching is not required.

If the required action is translate but the system clarifies, action/meaning/context fail (false abstention). If clarification is required but the system translates, the same three dimensions fail (unsafe guessing under this benchmark's policy). Generic clarification can preserve the decision to ask but fails context if it does not sufficiently request the missing information listed in the requirements.

Raters are independent AI sessions, not native Dutch human evaluators. Their judgments can share model biases and must not be treated as independent human certification. Disagreements are disclosed rather than silently selecting the more favorable score.
