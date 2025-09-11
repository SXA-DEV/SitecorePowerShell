﻿using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Text;
using Sitecore.Configuration;
using Sitecore.Data;
using Spe.Core.Extensions;
using Spe.Core.Modules;
using Spe.Core.Settings;

namespace Spe.Core.Host
{
    public static class CommandHelp
    {
        public static IEnumerable<string> GetHelp(ScriptSession session, string command)
        {
            var tokens = PSParser.Tokenize(command, out _);
            var lastPsToken = tokens.LastOrDefault(t => t.Type == PSTokenType.Command);
            if (lastPsToken != null)
            {
                session.Output.Clear();
                var lastToken = lastPsToken.Content;
                session.SetVariable("helpFor", lastToken);
                var platformmodule = ModuleManager.GetModule("Platform");
                var scriptItem = Database.GetDatabase(platformmodule.Database)
                                     .GetItem(platformmodule.Path + "/Internal/Context Help/Command Help") ??
                                 Factory.GetDatabase(ApplicationSettings.ScriptLibraryDb)
                                     .GetItem(ApplicationSettings.ScriptLibraryPath + "Internal/Context Help/Command Help");

                if (!scriptItem.IsPowerShellScript())
                {
                    return new[] { Texts.General_Operation_failed_wrong_data_template };
                }

                session.ExecuteScriptPart(scriptItem[Templates.Script.Fields.ScriptBody], true, true);

                if (session.Output.Count == 0 || session.Output[0].LineType == OutputLineType.Error)
                {
                    return new[]
                    {
                        "<div class='ps-help-command-name'>&nbsp;</div><div class='ps-help-header' align='center'>No Command in line or help information found</div><div class='ps-help-parameter' align='center'>Cannot provide help in this context.</div>"
                    };
                }

                var sb = new StringBuilder();

                session.Output.ForEach(l => sb.Append(l.Text));
                session.Output.Clear();

                var result = new[] { sb.ToString() };
                return result;
            }
            return new[] { "No Command in line found - cannot provide help in this context." };
        }
    }
}