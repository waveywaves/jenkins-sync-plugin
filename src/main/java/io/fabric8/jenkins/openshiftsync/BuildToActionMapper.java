package io.fabric8.jenkins.openshiftsync;

import hudson.model.Action;
import hudson.model.Cause;
import hudson.model.CauseAction;
import io.fabric8.openshift.api.model.Build;

import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

public class BuildToActionMapper {
  private static final Logger LOGGER = Logger.getLogger(BuildToActionMapper.class.getName());

  public static List<Action> updateCauseActionFromBuild(Build build, BuildConfigProjectProperty buildConfigProject) {
    // We need to ensure that we do not remove existing Causes from a Run since
    // other plugins may rely on them.
    List<Cause> newCauses = new ArrayList<>();
    newCauses.add(new BuildCause(build, buildConfigProject.getUid()));
    CauseAction originalCauseAction = BuildToActionMap.removeCauseAction(build.getMetadata().getName());
    if (originalCauseAction != null) {
        if (LOGGER.isLoggable(Level.FINE)) {
            LOGGER.fine("Adding existing causes...");
            for (Cause c : originalCauseAction.getCauses()) {
                LOGGER.fine("original cause: " + c.getShortDescription());
            }
        }
        newCauses.addAll(originalCauseAction.getCauses());
        if (LOGGER.isLoggable(Level.FINE)) {
            for (Cause c : newCauses) {
                LOGGER.fine("new cause: " + c.getShortDescription());
            }
        }
    }

    List<Action> buildActions = new ArrayList<>();
    CauseAction bCauseAction = new CauseAction(newCauses);
    buildActions.add(bCauseAction);
    BuildToActionMap.addCauseAction(build.getMetadata().getName(),bCauseAction);
    return buildActions;
  }
}
