insert into public.categories(name,slug) values
('Shirts','shirts'),('T-Shirts','t-shirts'),('Trousers','trousers'),('Outerwear','outerwear'),('Jeans','jeans'),('Cargos','cargos')
on conflict(slug) do nothing;
insert into public.inventory_locations(name,location_type) values('Main Store','store'),('Central Warehouse','warehouse') on conflict(name) do nothing;
