-- ============================================================
-- AKE Worker App - Reference Script
-- All tables already exist in Supabase.
-- This file contains only seed data and RLS policies.
-- ============================================================

-- ─────────────────────────────────────────────
-- SEED DATA — dropdown lookup values
-- ─────────────────────────────────────────────

INSERT INTO items (name) VALUES
  ('Screw M4'), ('Screw M6'), ('Bolt M8'), ('Nut M4'), ('Washer')
ON CONFLICT (name) DO NOTHING;

INSERT INTO threads (name) VALUES
  ('Metric'), ('Imperial'), ('UNC'), ('UNF'), ('BSW')
ON CONFLICT (name) DO NOTHING;

INSERT INTO lengths (value) VALUES
  ('10mm'), ('20mm'), ('30mm'), ('50mm'), ('100mm')
ON CONFLICT (value) DO NOTHING;

INSERT INTO heads (name) VALUES
  ('Hex'), ('Pan'), ('Round'), ('Flat'), ('Socket')
ON CONFLICT (name) DO NOTHING;

INSERT INTO colours (name) VALUES
  ('Natural'), ('Zinc Plated'), ('Black Oxide'), ('Hot Dip Galvanised'), ('Stainless')
ON CONFLICT (name) DO NOTHING;

-- ─────────────────────────────────────────────
-- ROW LEVEL SECURITY — Service role bypass
-- ─────────────────────────────────────────────

-- Service role bypass (backend uses service_role key)
CREATE POLICY "service_role_all" ON "Customer_Master"   FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all" ON "Item_Master"       FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all" ON "Sale_Transaction"  FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all" ON items              FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all" ON threads            FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all" ON lengths            FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all" ON heads              FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all" ON colours            FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────────
-- MOVEMENT LOGS
-- ─────────────────────────────────────────────
CREATE TABLE movement_logs ( 
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  date text, 
  activity text,
  item_id int,
  quantity real,
  uom text, 
  packet real, 
  per_packet real, 
  uom_packet text
);

-- ─────────────────────────────────────────────
-- ITEM WEIGHT UOM LOG
-- Stores individual dated entries for weight and sale rate per UoM.
-- Averages are computed from this table and written back to item_weight_uom.
-- ─────────────────────────────────────────────
CREATE TABLE public.item_weight_uom_log (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  item_id_uom       text NOT NULL,          -- "Name_Thread_Length_Head_Colour"
  date              text NOT NULL,          -- entry date (yyyy-MM-dd)
  uom               text NOT NULL,          -- UoM from LoV
  weight_per_uom    numeric(15, 3) NULL,    -- weight in KG, 3 decimal places
  weight_uom        text NULL,              -- always 'KG'
  sale_rate_per_uom numeric(12, 3) NULL,    -- sale rate for this UoM on this date
  quantity_per_uom  numeric(12, 3) NULL     -- quantity conversion (auto from UoM map)
) TABLESPACE pg_default;

-- RLS: service role bypass
CREATE POLICY "service_role_all" ON item_weight_uom_log FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all" ON item_weight_uom     FOR ALL TO service_role USING (true) WITH CHECK (true);

