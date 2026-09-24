package com.microsoft.microhack.catalog.service;

import java.util.concurrent.atomic.AtomicReference;
import org.springframework.stereotype.Component;

/** Tracks startup import readiness independently from process liveness. */
@Component
public class StartupState {

    public enum Status {
        NOT_READY,
        READY,
        FAILED
    }

    private final AtomicReference<Status> status = new AtomicReference<>(Status.NOT_READY);

    public Status status() {
        return status.get();
    }

    public void ready() {
        status.set(Status.READY);
    }

    public void failed() {
        status.set(Status.FAILED);
    }
}
