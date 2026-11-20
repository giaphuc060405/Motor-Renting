create table public.roles (
    role_id   int generated always as identity primary key,
    role_name varchar(50) not null unique
);

create table public.license_classes (
    class_id   int generated always as identity primary key,
    class_name varchar(10) not null unique
);

create table public.statuses (
    status_id   int generated always as identity primary key,
    status_name varchar(50) not null unique
);

create table public.motor_types (
    type_id   int generated always as identity primary key,
    type_name varchar(50) not null unique
);

create table public.staffs (
    staff_id   uuid primary key references auth.users(id) on delete cascade,
    full_name  varchar(100) not null,
    phone      varchar(15)  not null unique,
    email      varchar(100) not null unique,
    role_id    int not null references public.roles(role_id),
    is_deleted boolean not null default false,
    created_at timestamptz not null default now()
);

create table public.fields (
    field_id   int generated always as identity primary key,
    field_name varchar(100) not null,
    class_id   int not null references public.license_classes(class_id),
    status_id  int not null references public.statuses(status_id),
    is_deleted boolean not null default false,
    created_at timestamptz not null default now()
);


create table public.motors (
    motor_id      int generated always as identity primary key,
    motor_name    varchar(100) not null,
    type_id       int not null references public.motor_types(type_id),
    class_id      int not null references public.license_classes(class_id),
    license_plate varchar(20)  not null,
    status_id     int not null references public.statuses(status_id),
    field_id      int null references public.fields(field_id) on delete set null,
    is_deleted    boolean not null default false,
    created_at    timestamptz not null default now()
);

create unique index uq_fields_name_active on public.fields (field_name)    where is_deleted = false;
create unique index uq_motors_plate_active on public.motors (license_plate) where is_deleted = false;

create index idx_motors_field  on public.motors (field_id);
create index idx_motors_status on public.motors (status_id);
create index idx_staffs_role   on public.staffs (role_id);

create view public.fields_with_motor_count
with (security_invoker = true) as
select f.field_id, f.field_name, f.class_id, f.status_id,
       count(m.motor_id) as motor_count
from public.fields f
left join public.motors m
       on m.field_id = f.field_id and m.is_deleted = false
where f.is_deleted = false
group by f.field_id;

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public as $$
    select exists (
        select 1 from public.staffs s
        where s.staff_id = auth.uid() and s.is_deleted = false
    );
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
    select exists (
        select 1 from public.staffs s
        join public.roles r on r.role_id = s.role_id
        where s.staff_id = auth.uid()
          and s.is_deleted = false
          and r.role_name = 'Admin'
    );
$$;

alter table public.roles           enable row level security;
alter table public.license_classes enable row level security;
alter table public.statuses        enable row level security;
alter table public.motor_types     enable row level security;
alter table public.staffs          enable row level security;
alter table public.fields          enable row level security;
alter table public.motors          enable row level security;

do $$
declare t text;
begin
    foreach t in array array['roles','license_classes','statuses','motor_types'] loop
        execute format('create policy "%1$s_select" on public.%1$s for select to authenticated using (public.is_staff())', t);
        execute format('create policy "%1$s_insert" on public.%1$s for insert to authenticated with check (public.is_admin())', t);
        execute format('create policy "%1$s_update" on public.%1$s for update to authenticated using (public.is_admin()) with check (public.is_admin())', t);
        execute format('create policy "%1$s_delete" on public.%1$s for delete to authenticated using (public.is_admin())', t);
    end loop;
end $$;

create policy "staffs_select" on public.staffs for select to authenticated
    using (public.is_admin() or (staff_id = auth.uid() and is_deleted = false));
create policy "staffs_insert" on public.staffs for insert to authenticated
    with check (public.is_admin());
create policy "staffs_update" on public.staffs for update to authenticated
    using (public.is_admin()) with check (public.is_admin());
create policy "staffs_delete" on public.staffs for delete to authenticated
    using (public.is_admin());

create policy "fields_select" on public.fields for select to authenticated
    using (public.is_admin() or (public.is_staff() and is_deleted = false));
create policy "fields_insert" on public.fields for insert to authenticated
    with check (public.is_admin());
create policy "fields_update" on public.fields for update to authenticated
    using (public.is_admin()) with check (public.is_admin());
create policy "fields_delete" on public.fields for delete to authenticated
    using (public.is_admin());


create policy "motors_select" on public.motors for select to authenticated
    using (public.is_admin() or (public.is_staff() and is_deleted = false));
create policy "motors_insert" on public.motors for insert to authenticated
    with check (public.is_admin());
create policy "motors_update" on public.motors for update to authenticated
    using (public.is_admin() or (public.is_staff() and is_deleted = false))
    with check (public.is_admin() or (public.is_staff() and is_deleted = false));
create policy "motors_delete" on public.motors for delete to authenticated
    using (public.is_admin());

create or replace function public.motors_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
    v_active int;
    v_field  record;
begin
    select status_id into v_active from statuses where status_name = 'Hoạt động';

    if tg_op = 'UPDATE' and auth.uid() is not null and not public.is_admin() then
        if (new.motor_name, new.type_id, new.class_id, new.license_plate, new.status_id, new.is_deleted)
           is distinct from
           (old.motor_name, old.type_id, old.class_id, old.license_plate, old.status_id, old.is_deleted) then
            raise exception 'Nhân viên chỉ được phép thay đổi sân tập của xe';
        end if;
    end if;

    if new.status_id <> v_active or new.is_deleted then
        new.field_id := null;
    end if;

    -- Kiểm tra khi gán sân
    if new.field_id is not null then
        select * into v_field from fields where field_id = new.field_id;

        if v_field.is_deleted or v_field.status_id <> v_active then
            raise exception 'Sân đang bảo trì hoặc đã bị xóa, không thể gán xe';
        end if;
        if v_field.class_id <> new.class_id then
            raise exception 'Xe chỉ được gán vào sân cùng bảng (A1 hoặc A)';
        end if;
    end if;

    return new;
end;
$$;

create trigger trg_motors_guard
before insert or update on public.motors
for each row execute function public.motors_guard();

create or replace function public.fields_after_update()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_active int;
begin
    select status_id into v_active from statuses where status_name = 'Hoạt động';

    if new.status_id <> v_active or new.is_deleted or new.class_id <> old.class_id then
        update motors
           set field_id = null
         where field_id = new.field_id
           and (new.status_id <> v_active or new.is_deleted or class_id <> new.class_id);
    end if;
    return new;
end;
$$;

create trigger trg_fields_after_update
after update on public.fields
for each row execute function public.fields_after_update();

create or replace function public.staffs_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
    v_admin_role int;
    v_other_admins int;
begin
    select role_id into v_admin_role from roles where role_name = 'Admin';

    if old.role_id = v_admin_role and old.is_deleted = false
       and (tg_op = 'DELETE' or new.is_deleted or new.role_id <> old.role_id) then
        select count(*) into v_other_admins from staffs
         where role_id = v_admin_role and is_deleted = false and staff_id <> old.staff_id;
        if v_other_admins = 0 then
            raise exception 'Không thể xóa hoặc hạ quyền Admin cuối cùng';
        end if;
    end if;

    if tg_op = 'DELETE' then return old; end if;
    return new;
end;
$$;

create trigger trg_staffs_guard
before update or delete on public.staffs
for each row execute function public.staffs_guard();

insert into public.roles (role_name) values ('Admin'), ('Nhân viên');
insert into public.license_classes (class_name) values ('A1'), ('A');
insert into public.statuses (status_name) values ('Hoạt động'), ('Đang bảo trì');
insert into public.motor_types (type_name) values ('Xe ga'), ('Xe số'), ('PKL');

insert into public.staffs (staff_id, full_name, phone, email, role_id)
select u.id, 'Admin', '0987654321', u.email,
       (select role_id from public.roles where role_name = 'Admin')
from auth.users u
where u.email = 'admin@motorrenting.com'


insert into public.fields (field_name, class_id, status_id)
select v.name,
       (select class_id  from public.license_classes where class_name  = v.cls),
       (select status_id from public.statuses        where status_name = v.st)
from (values
    ('Sân A1 số 1', 'A1', 'Hoạt động'),
    ('Sân A1 số 2', 'A1', 'Hoạt động'),
    ('Sân A1 số 3', 'A1', 'Hoạt động'),
    ('Sân A số 1',  'A',  'Hoạt động'),
    ('Sân A số 2',  'A',  'Đang bảo trì')
) as v(name, cls, st);

insert into public.motors (motor_name, type_id, class_id, license_plate, status_id)
select v.name,
       (select type_id   from public.motor_types     where type_name   = v.typ),
       (select class_id  from public.license_classes where class_name  = v.cls),
       v.plate,
       (select status_id from public.statuses        where status_name = v.st)
from (values
    ('Honda Vision',     'Xe ga',  'A1', '29-AB 226.58', 'Hoạt động'),
    ('Yamaha Janus',     'Xe ga',  'A1', '29-AC 257.67', 'Hoạt động'),
    ('Honda Air Blade',  'Xe ga',  'A1', '29-DC 178.55', 'Hoạt động'),
    ('Honda Wave Alpha', 'Xe số',  'A1', '29-GH 124.56', 'Hoạt động'),
    ('Yamaha Sirius',    'Xe số',  'A1', '29-DD 122.13', 'Hoạt động'),
    ('Honda Rebel 500',  'PKL',    'A',  '29-GG 615.57', 'Hoạt động'),
    ('Kawasaki Z650',    'PKL',    'A',  '29-TY 456.12', 'Hoạt động'),
    ('Suzuki Impulse',   'Xe ga',  'A1', '29-CC 654.77', 'Đang bảo trì'),
    ('Honda Future',     'Xe số',  'A1', '29-HH 321.45', 'Đang bảo trì'),
    ('Yamaha MT-07',     'PKL',    'A',  '29-KK 987.65', 'Đang bảo trì')
) as v(name, typ, cls, plate, st);