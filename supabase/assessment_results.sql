-- =========================================================
-- Data & ML Readiness Assessment: one row per submission.
-- The site sends only contact details and the 20 answers;
-- scores and tier are computed here so they cannot be forged.
-- =========================================================

create table if not exists public.assessment_results (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),

  email       text not null check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(email) <= 254),
  name        text check (length(name) <= 200),
  company     text check (length(company) <= 200),

  -- q1..q20, each 1-5, in form order
  answers     smallint[] not null check (
                array_length(answers, 1) = 20
                and 1 <= all(answers) and 5 >= all(answers)),

  -- filled by the trigger below
  score_infrastructure smallint,
  score_kpi            smallint,
  score_workflow       smallint,
  score_leadership     smallint,
  total                smallint,
  tier                 text
);

create or replace function public.assessment_results_score()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.score_infrastructure := new.answers[1]  + new.answers[2]  + new.answers[3]  + new.answers[4]  + new.answers[5];
  new.score_kpi            := new.answers[6]  + new.answers[7]  + new.answers[8]  + new.answers[9]  + new.answers[10];
  new.score_workflow       := new.answers[11] + new.answers[12] + new.answers[13] + new.answers[14] + new.answers[15];
  new.score_leadership     := new.answers[16] + new.answers[17] + new.answers[18] + new.answers[19] + new.answers[20];
  new.total := new.score_infrastructure + new.score_kpi + new.score_workflow + new.score_leadership;
  -- same thresholds as the results page
  new.tier := case
    when new.total >= 80 then 'Production Ready'
    when new.total >= 55 then 'Targeted Deployment'
    when new.total >= 30 then 'Foundation Phase'
    else 'Initial Stage'
  end;
  new.id := gen_random_uuid();
  new.created_at := now();
  return new;
end;
$$;

drop trigger if exists assessment_results_score on public.assessment_results;
create trigger assessment_results_score
  before insert on public.assessment_results
  for each row execute function public.assessment_results_score();

-- Visitors may insert, never read, update or delete.
alter table public.assessment_results enable row level security;

revoke all on public.assessment_results from anon, authenticated;
grant insert (email, name, company, answers) on public.assessment_results to anon;

drop policy if exists "website can submit" on public.assessment_results;
create policy "website can submit"
  on public.assessment_results
  for insert to anon
  with check (true);
