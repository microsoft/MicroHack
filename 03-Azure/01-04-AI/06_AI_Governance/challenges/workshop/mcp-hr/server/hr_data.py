from __future__ import annotations

import hashlib
import random
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from typing import Any


DEMO_SEED = "contoso-hr-mcp-demo-v1"


@dataclass
class Employee:
    employee_id: str
    name: str
    department: str
    role: str
    location: str
    manager_id: str | None
    hire_date: date
    skills: list[str]
    goals: list[str]
    pto_accrued_days: int
    pto_used_days: int
    skill_evidence: list[dict[str, Any]] = field(default_factory=list)


class HRStore:
    def __init__(self) -> None:
        self.employees = self._seed_employees()
        self.pto_requests: list[dict[str, Any]] = []
        self.skill_updates: list[dict[str, Any]] = []

    def _seed_employees(self) -> dict[str, Employee]:
        first_names = [
            "Avery",
            "Jordan",
            "Morgan",
            "Riley",
            "Taylor",
            "Casey",
            "Sam",
            "Jamie",
            "Priya",
            "Diego",
            "Mina",
            "Noah",
        ]
        last_names = [
            "Chen",
            "Patel",
            "Garcia",
            "Smith",
            "Brown",
            "Kim",
            "Okafor",
            "Nakamura",
            "Silva",
            "Johnson",
            "Müller",
            "Singh",
        ]
        departments = {
            "People": ["HR Business Partner", "Recruiter", "Learning Specialist"],
            "Engineering": ["Software Engineer", "Platform Engineer", "Engineering Manager"],
            "Sales": ["Account Executive", "Solution Specialist", "Sales Manager"],
            "Finance": ["Financial Analyst", "Controller", "Procurement Lead"],
            "Support": ["Support Engineer", "Customer Success Manager", "Escalation Lead"],
        }
        locations = ["Seattle", "London", "Tokyo", "Berlin", "Toronto", "Bengaluru"]
        skill_pool = {
            "People": ["coaching", "employee relations", "workforce planning", "facilitation"],
            "Engineering": ["python", "azure", "api design", "incident response", "security"],
            "Sales": ["negotiation", "crm", "discovery", "forecasting"],
            "Finance": ["budgeting", "excel", "risk controls", "vendor management"],
            "Support": ["troubleshooting", "customer empathy", "kql", "runbooks"],
        }
        goals_pool = [
            "manager readiness",
            "technical leadership",
            "customer storytelling",
            "automation",
            "cross-functional collaboration",
            "operational excellence",
        ]

        employees: dict[str, Employee] = {}
        index = 1001
        for dept, roles in departments.items():
            for role in roles:
                rng = random.Random(f"{DEMO_SEED}:{dept}:{role}")
                employee_id = f"E{index}"
                name = f"{rng.choice(first_names)} {rng.choice(last_names)}"
                hire_year = 2016 + rng.randrange(0, 9)
                hire_month = rng.randrange(1, 13)
                hire_day = min(28, 1 + rng.randrange(0, 28))
                skills = rng.sample(skill_pool[dept] + ["communication", "analytics", "presentation"], 4)
                goals = rng.sample(goals_pool, 2)
                accrued = 18 + rng.randrange(0, 9)
                used = rng.randrange(0, max(1, accrued - 3))
                employees[employee_id] = Employee(
                    employee_id=employee_id,
                    name=name,
                    department=dept,
                    role=role,
                    location=rng.choice(locations),
                    manager_id=None,
                    hire_date=date(hire_year, hire_month, hire_day),
                    skills=sorted(set(skills)),
                    goals=goals,
                    pto_accrued_days=accrued,
                    pto_used_days=used,
                )
                index += 1

        ids = list(employees)
        for employee in employees.values():
            if "Manager" not in employee.role and "Lead" not in employee.role and "Controller" not in employee.role:
                candidates = [
                    e.employee_id
                    for e in employees.values()
                    if e.department == employee.department and e.employee_id != employee.employee_id
                ]
                employee.manager_id = candidates[0] if candidates else None
        return employees

    def search_employees(self, query: str, department: str | None = None, location: str | None = None) -> dict[str, Any]:
        terms = [t.lower() for t in query.split() if t.strip()]
        department_filter = department.lower() if department else None
        location_filter = location.lower() if location else None
        results = []
        for employee in self.employees.values():
            if department_filter and employee.department.lower() != department_filter:
                continue
            if location_filter and employee.location.lower() != location_filter:
                continue
            haystack = " ".join(
                [
                    employee.employee_id,
                    employee.name,
                    employee.department,
                    employee.role,
                    employee.location,
                    " ".join(employee.skills),
                    " ".join(employee.goals),
                ]
            ).lower()
            score = sum(3 if term in employee.name.lower() else 1 for term in terms if term in haystack)
            if not terms:
                score = 1
            if score:
                results.append((score, employee))
        results.sort(key=lambda item: (-item[0], item[1].name))
        return {
            "query": query,
            "filters": {"department": department, "location": location},
            "result_count": len(results),
            "employees": [self._employee_summary(employee, score) for score, employee in results[:10]],
        }

    def get_employee_profile(self, employee_id: str) -> dict[str, Any]:
        employee = self.employees.get(employee_id.upper())
        if not employee:
            return self._error("NOT_FOUND", f"Employee {employee_id} was not found.", ["Call `search_employees` to find a valid employee_id."])
        today = date.today()
        pending_pto = [r for r in self.pto_requests if r["employee_id"] == employee.employee_id and r["status"] == "PENDING_REVIEW"]
        return {
            **self._employee_summary(employee, score=None),
            "hire_date": employee.hire_date.isoformat(),
            "tenure_years": round((today - employee.hire_date).days / 365.25, 1),
            "manager_id": employee.manager_id,
            "goals": employee.goals,
            "pto": self._pto_snapshot(employee),
            "pending_pto_requests": pending_pto,
            "skill_evidence": employee.skill_evidence[-5:],
            "generated_at": datetime.now(timezone.utc).isoformat(),
        }

    def recommend_learning_path(self, employee_id: str, target_role: str) -> dict[str, Any]:
        employee = self.employees.get(employee_id.upper())
        if not employee:
            return self._error("NOT_FOUND", f"Employee {employee_id} was not found.", ["Call `search_employees` to find a valid employee_id."])
        target_requirements = self._target_role_skills(target_role)
        current = {skill.lower() for skill in employee.skills}
        missing = [skill for skill in target_requirements if skill.lower() not in current]
        tenure_days = max(1, (date.today() - employee.hire_date).days)
        pace = "accelerated" if tenure_days > 365 * 3 and len(missing) <= 3 else "standard"
        modules = [
            {
                "module": f"{skill.title()} applied lab",
                "skill": skill,
                "duration_hours": 2 + stable_int(employee.employee_id, skill, modulo=5),
                "due_date": add_business_days(date.today(), 10 + i * (7 if pace == "accelerated" else 14)).isoformat(),
            }
            for i, skill in enumerate(missing[:5])
        ]
        confidence = round(0.62 + min(0.28, len(set(target_requirements) & current) * 0.07), 2)
        return {
            "employee_id": employee.employee_id,
            "current_role": employee.role,
            "target_role": target_role,
            "pace": pace,
            "matched_skills": sorted(set(target_requirements) & current),
            "skill_gaps": missing,
            "recommended_modules": modules,
            "mentor_suggestion": self._mentor_for(target_requirements, employee.employee_id),
            "confidence": confidence,
            "generated_for_date": date.today().isoformat(),
        }

    def submit_pto_request(self, employee_id: str, start_date: str, end_date: str, reason: str) -> dict[str, Any]:
        employee = self.employees.get(employee_id.upper())
        if not employee:
            return self._error("NOT_FOUND", f"Employee {employee_id} was not found.", ["Call `search_employees` to find a valid employee_id."])
        try:
            start = date.fromisoformat(start_date)
            end = date.fromisoformat(end_date)
        except ValueError:
            return self._error("INVALID_DATE", "Dates must use ISO format YYYY-MM-DD.", ["Retry `submit_pto_request` with valid start_date and end_date."])
        if end < start:
            return self._error("INVALID_DATE_RANGE", "end_date must be on or after start_date.", ["Retry with an end_date on or after start_date."])
        if start < date.today():
            return self._error("PAST_DATE", "PTO cannot start in the past.", ["Retry with a future start_date."])
        business_days = count_business_days(start, end)
        if business_days <= 0:
            return self._error("NO_BUSINESS_DAYS", "Request does not include any business days.", ["Choose a range with at least one weekday."])
        balance = self._pto_snapshot(employee)["remaining_days"]
        overlapping = [
            r["request_id"]
            for r in self.pto_requests
            if r["employee_id"] == employee.employee_id
            and r["status"] != "CANCELLED"
            and not (end < date.fromisoformat(r["start_date"]) or start > date.fromisoformat(r["end_date"]))
        ]
        if overlapping:
            return self._error("STATE_CONFLICT", "Requested dates overlap an existing PTO request.", [f"Review existing request(s): {', '.join(overlapping)}."])
        if business_days > balance:
            return self._error("INSUFFICIENT_BALANCE", f"Requested {business_days} days but only {balance} are available.", ["Shorten the date range or contact HR for leave options."])
        request_id = f"PTO-{datetime.now(timezone.utc).strftime('%Y%m%d')}-{stable_int(employee.employee_id, start_date, end_date, modulo=9000) + 1000}"
        record = {
            "request_id": request_id,
            "employee_id": employee.employee_id,
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
            "business_days": business_days,
            "reason_category": categorize_reason(reason),
            "status": "PENDING_REVIEW" if business_days > 5 else "AUTO_APPROVED",
            "submitted_at": datetime.now(timezone.utc).isoformat(),
            "manager_id": employee.manager_id,
        }
        self.pto_requests.append(record)
        if record["status"] == "AUTO_APPROVED":
            employee.pto_used_days += business_days
        return {"ok": True, "pto_request": record, "pto_balance": self._pto_snapshot(employee)}

    def update_employee_skills(self, employee_id: str, skills: list[str], evidence_note: str) -> dict[str, Any]:
        employee = self.employees.get(employee_id.upper())
        if not employee:
            return self._error("NOT_FOUND", f"Employee {employee_id} was not found.", ["Call `search_employees` to find a valid employee_id."])
        normalized = sorted({skill.strip().lower() for skill in skills if skill and skill.strip()})
        if not normalized:
            return self._error("VALIDATION_ERROR", "At least one non-empty skill is required.", ["Retry with skills like ['python', 'facilitation']."])
        if len(evidence_note.strip()) < 12:
            return self._error("INSUFFICIENT_EVIDENCE", "evidence_note must describe where the skills were demonstrated.", ["Include a project, course, manager note, or assessment result."])
        existing = {skill.lower() for skill in employee.skills}
        added = [skill for skill in normalized if skill not in existing]
        already_present = [skill for skill in normalized if skill in existing]
        employee.skills = sorted(set(employee.skills) | set(added))
        event = {
            "update_id": f"SKILL-{stable_int(employee.employee_id, evidence_note, modulo=900000) + 100000}",
            "employee_id": employee.employee_id,
            "added_skills": added,
            "already_present": already_present,
            "evidence_note": evidence_note.strip(),
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        employee.skill_evidence.append(event)
        self.skill_updates.append(event)
        return {"ok": True, "skill_update": event, "current_skills": employee.skills}

    def _employee_summary(self, employee: Employee, score: int | None) -> dict[str, Any]:
        payload = {
            "employee_id": employee.employee_id,
            "name": employee.name,
            "department": employee.department,
            "role": employee.role,
            "location": employee.location,
            "skills": employee.skills,
        }
        if score is not None:
            payload["match_score"] = score
        return payload

    def _pto_snapshot(self, employee: Employee) -> dict[str, Any]:
        pending_days = sum(r["business_days"] for r in self.pto_requests if r["employee_id"] == employee.employee_id and r["status"] == "PENDING_REVIEW")
        return {
            "accrued_days": employee.pto_accrued_days,
            "used_days": employee.pto_used_days,
            "pending_days": pending_days,
            "remaining_days": max(0, employee.pto_accrued_days - employee.pto_used_days - pending_days),
            "as_of": date.today().isoformat(),
        }

    def _target_role_skills(self, target_role: str) -> list[str]:
        role = target_role.lower()
        base = ["communication", "analytics"]
        if "manager" in role or "lead" in role:
            return base + ["coaching", "planning", "stakeholder management", "decision making"]
        if "engineer" in role or "architect" in role:
            return base + ["python", "azure", "api design", "security", "incident response"]
        if "sales" in role or "account" in role:
            return base + ["negotiation", "crm", "customer storytelling", "forecasting"]
        if "finance" in role:
            return base + ["budgeting", "risk controls", "vendor management"]
        return base + ["presentation", "cross-functional collaboration", "automation"]

    def _mentor_for(self, required_skills: list[str], employee_id: str) -> dict[str, Any] | None:
        required = {skill.lower() for skill in required_skills}
        candidates = [
            (len(required & {skill.lower() for skill in employee.skills}), employee)
            for employee in self.employees.values()
            if employee.employee_id != employee_id
        ]
        candidates = [candidate for candidate in candidates if candidate[0] > 0]
        if not candidates:
            return None
        score, employee = sorted(candidates, key=lambda item: (-item[0], item[1].name))[0]
        return {"employee_id": employee.employee_id, "name": employee.name, "role": employee.role, "matched_skill_count": score}

    def _error(self, error: str, message: str, next_steps: list[str]) -> dict[str, Any]:
        return {"ok": False, "error": error, "message": message, "next_steps": next_steps}


def stable_int(*parts: str, modulo: int) -> int:
    digest = hashlib.sha256(":".join(parts).encode("utf-8")).hexdigest()
    return int(digest[:12], 16) % modulo


def count_business_days(start: date, end: date) -> int:
    days = 0
    cursor = start
    while cursor <= end:
        if cursor.weekday() < 5:
            days += 1
        cursor = date.fromordinal(cursor.toordinal() + 1)
    return days


def add_business_days(start: date, days: int) -> date:
    cursor = start
    remaining = days
    while remaining:
        cursor = date.fromordinal(cursor.toordinal() + 1)
        if cursor.weekday() < 5:
            remaining -= 1
    return cursor


def categorize_reason(reason: str) -> str:
    lowered = reason.lower()
    if any(word in lowered for word in ["sick", "medical", "doctor"]):
        return "medical"
    if any(word in lowered for word in ["family", "care", "child"]):
        return "family"
    if any(word in lowered for word in ["vacation", "holiday", "travel"]):
        return "vacation"
    return "personal"
