import { promises as fs } from "node:fs";
import path from "node:path";
import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";
export const maxDuration = 300;

type ExportFile = { relativePath: string; base64: string };

function safeRel(p: string) {
  const normalized = path.normalize(p).replace(/^(\.\.(\/|\\|$))+/, "");
  if (normalized.includes("..") || path.isAbsolute(normalized)) {
    throw new Error(`Unsafe path: ${p}`);
  }
  return normalized;
}

export async function POST(req: Request) {
  let body: { files?: ExportFile[]; clearDir?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON" }, { status: 400 });
  }

  const files = Array.isArray(body.files) ? body.files : [];
  if (!files.length && !body.clearDir) {
    return NextResponse.json({ ok: false, error: "No files" }, { status: 400 });
  }

  const root = path.join(process.cwd(), "exports");
  try {
    if (body.clearDir) {
      const clearTarget = path.join(root, safeRel(body.clearDir));
      await fs.rm(clearTarget, { recursive: true, force: true });
    }

    const written: string[] = [];
    for (const file of files) {
      const rel = safeRel(file.relativePath);
      const dest = path.join(root, rel);
      await fs.mkdir(path.dirname(dest), { recursive: true });
      await fs.writeFile(dest, Buffer.from(file.base64, "base64"));
      written.push(rel);
    }
    return NextResponse.json({ ok: true, count: written.length, written });
  } catch (e) {
    return NextResponse.json(
      { ok: false, error: e instanceof Error ? e.message : String(e) },
      { status: 500 },
    );
  }
}
