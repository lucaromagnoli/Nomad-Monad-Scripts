from contextlib import contextmanager
from typing import Optional

import reapy

from custom_errors import ResampleError
from models import ResampleTrack


def get_selected_track(project: 'reapy.Project') -> 'reapy.Track':
    track = project.get_selected_track(0)
    if not track.has_valid_id:
        raise ResampleError('No track selected')
    return track


def track_has_instrument(track: 'reapy.Track', raise_: bool = False):
    if track.instrument is None:
        if raise_:
            raise ResampleError('Track has no instrument')
        else:
            return False
    return True


def create_new_rsmpl_track(
        project: 'reapy.Project',
        parent_track: 'reapy.Track',
        route_midi: bool = True,
        delete_fx: bool = True
) -> 'ResampleTrack':
    track = ResampleTrack.from_source_track(project, parent_track)
    send = parent_track.add_send(track)
    if route_midi:
        send.set_sws_info('I_MIDI_SRCCHAN', 0)
    while track.n_fxs > 0:
        track.fxs[0].delete()
    for i, fx in enumerate(parent_track.fxs):
        if fx.index != parent_track.instrument.index:
            fx.copy_to_track(track, index=i)
    if delete_fx:
        while parent_track.n_fxs > 1:
            parent_track.fxs[-1].delete()
    parent_track.set_info_value('B_MAINSEND', 0)
    return track


def save_resample_track(project: 'reapy.Project', source_track: 'reapy.Track', resample_track: 'ResampleTrack'):
    project.set_ext_state('source_track_to_rsmpl', source_track.GUID, resample_track, pickled=True)
    project.set_ext_state('is_resample_track', resample_track.GUID, True, pickled=True)


def get_resample_track_by_source_track(project: 'reapy.Project', source_track: 'reapy.Track') -> Optional['reapy.Track']:
    track = project.get_ext_state('source_track_to_rsmpl', source_track.GUID, pickled=True) # noqa
    if not track:
        return None
    elif not track.has_valid_id:
        project.set_ext_state('source_track_to_rsmpl', source_track.GUID, None, pickled=True)  # noqa
        return None
    else:
        return track


def track_is_resample_track(project: 'reapy.Project', track: 'reapy.Track'):
    return bool(project.get_ext_state('resample.is_resample_track', track.id, pickled=True))


@contextmanager
def undo_context(project: 'reapy.Project'):
    try:
        project.begin_undo_block()
        yield
    finally:
        project.end_undo_block()
