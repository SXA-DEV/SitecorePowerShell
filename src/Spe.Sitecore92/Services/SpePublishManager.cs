using Sitecore.Publishing;
using Sitecore.Publishing.Pipelines.Publish;
using Spe.Abstractions.VersionDecoupling.Interfaces;
using System.Reflection;

namespace Spe.VersionSpecific.Services
{
    public class SpePublishManager : IPublishManager
    {
        public IJob PublishAsync(PublishOptions options)
        {
            var publisher = new Publisher(options);
            var job = publisher.PublishAsync();

            return new SpeJob(job);
        }

        public PublishResult PublishSync(PublishOptions options)
        {
            var publishContext = PublishManager.CreatePublishContext(options);
            publishContext.Languages = new[] { options.Language };
            publishContext.Job = Sitecore.Context.Job;

            // #1382 hotfix
            var field = publishContext.Job.Options.Method.GetType().GetField("m_object", BindingFlags.NonPublic | BindingFlags.Instance);
            field.SetValue(publishContext.Job.Options.Method, new Sitecore.Publishing.Publisher(options));
            // #1382 hotfix - end

            return PublishPipeline.Run(publishContext);
        }
    }
}
