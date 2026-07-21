// MigracionTool.cs
// -----------------------------------------------------------------------------
// Genera una migración EF6 sin la Package Manager Console.
// Útil cuando la PMC está rota (ej. VS Insiders, bug IsWebSiteProject) y no hay
// dotnet ef (que es exclusivo de EF Core). Hace lo mismo que Add-Migration por
// dentro: MigrationScaffolder.Scaffold, que compara el modelo compilado contra el
// snapshot de la última migración y emite los 3 archivos (.cs, .Designer.cs, .resx).
//
// Uso:
//   MigracionTool.exe <NombreMigracion> [--empty] [--out <carpeta>]
//     <NombreMigracion>  nombre de la clase de migración (ej. ResyncSnapshot).
//     --empty            migración VACÍA (ignoreChanges): solo refresca el snapshot,
//                        sin operaciones de esquema. No exige base sincronizada.
//     (sin --empty)      diff normal: requiere una base sincronizada con TODAS las
//                        migraciones o tira MigrationsPendingException.
//     --out <carpeta>    carpeta de salida (default: .\_migracion_generada).
//
// Requisitos de compilación/ejecución: ver README.md (se compila con csc contra los
// binarios del DAL ya construidos, y necesita un MigracionTool.exe.config con la
// connection string del contexto).
// -----------------------------------------------------------------------------
using System;
using System.Collections.Generic;
using System.Data.Entity.Migrations.Design;
using System.Data.Entity.Migrations.Infrastructure;
using System.IO;
using System.Xml.Linq;
using Capsa.OyG.Dal.Migrations; // Configuration (clase de config de migraciones del DAL)

class MigracionTool
{
    static int Main(string[] args)
    {
        if (args.Length == 0 || args[0].StartsWith("--"))
        {
            Console.WriteLine("Uso: MigracionTool.exe <NombreMigracion> [--empty] [--out <carpeta>]");
            return 64;
        }

        string nombre = args[0];
        bool ignoreChanges = Array.IndexOf(args, "--empty") >= 0;
        string outDir = ArgValue(args, "--out")
                        ?? Path.Combine(Directory.GetCurrentDirectory(), "_migracion_generada");

        try
        {
            var scaffolder = new MigrationScaffolder(new Configuration());
            ScaffoldedMigration m = ignoreChanges
                ? scaffolder.Scaffold(nombre, true)
                : scaffolder.Scaffold(nombre);

            Directory.CreateDirectory(outDir);
            File.WriteAllText(Path.Combine(outDir, m.MigrationId + ".cs"), m.UserCode);
            File.WriteAllText(Path.Combine(outDir, m.MigrationId + ".Designer.cs"), m.DesignerCode);
            EscribirResx(Path.Combine(outDir, m.MigrationId + ".resx"), m.Resources);

            Console.WriteLine("=== OK ===");
            Console.WriteLine("MigrationId : " + m.MigrationId);
            Console.WriteLine("Modo        : " + (ignoreChanges ? "ignoreChanges (migración vacía)" : "diff normal"));
            Console.WriteLine("Archivos en : " + outDir);
            Console.WriteLine();
            Console.WriteLine("=== UserCode (Up/Down) ===");
            Console.WriteLine(m.UserCode);
            return 0;
        }
        catch (MigrationsPendingException ex)
        {
            Console.WriteLine("=== MigrationsPendingException ===");
            Console.WriteLine(ex.Message);
            Console.WriteLine();
            Console.WriteLine(">> La base no tiene todas las migraciones aplicadas.");
            Console.WriteLine(">> Apuntá a una base sincronizada, o usá --empty (re-baseline sin diff).");
            return 2;
        }
        catch (Exception ex)
        {
            Console.WriteLine("=== ERROR: " + ex.GetType().FullName + " ===");
            Console.WriteLine(ex.Message);
            for (var inner = ex.InnerException; inner != null; inner = inner.InnerException)
                Console.WriteLine("INNER (" + inner.GetType().Name + "): " + inner.Message);
            Console.WriteLine();
            Console.WriteLine(ex.StackTrace);
            return 1;
        }
    }

    static string ArgValue(string[] args, string flag)
    {
        int i = Array.IndexOf(args, flag);
        return (i >= 0 && i + 1 < args.Length) ? args[i + 1] : null;
    }

    // Escribe un .resx estándar sin depender de System.Windows.Forms (ResXResourceWriter).
    static void EscribirResx(string path, IEnumerable<KeyValuePair<string, object>> resources)
    {
        var root = new XElement("root",
            Header("resmimetype", "text/microsoft-resx"),
            Header("version", "2.0"),
            Header("reader", "System.Resources.ResXResourceReader, System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"),
            Header("writer", "System.Resources.ResXResourceWriter, System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"));

        foreach (var kv in resources)
        {
            root.Add(new XElement("data",
                new XAttribute("name", kv.Key),
                new XAttribute(XNamespace.Xml + "space", "preserve"),
                new XElement("value", Convert.ToString(kv.Value))));
        }

        new XDocument(new XDeclaration("1.0", "utf-8", "yes"), root).Save(path);
    }

    static XElement Header(string name, string value)
    {
        return new XElement("resheader", new XAttribute("name", name), new XElement("value", value));
    }
}
