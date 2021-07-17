from typing import TYPE_CHECKING

from models import ResampleTrack
from custom_errors import ResampleError

if TYPE_CHECKING:
    import reapy


def get_selected_track(project: 'reapy.Project') -> 'reapy.Track':
    track = project.get_selected_track(0)
    if not track.has_valid_id:
        raise ResampleError('No track selected')
    if track.instrument is None:
        raise ResampleError('Track has no instrument')
    return track


def create_new_rsmpl_track(project: 'reapy.Project', parent_track: 'reapy.Track', route_midi: bool = True) -> 'ResampleTrack':
    track = ResampleTrack.from_source_track(project, parent_track)
    send = parent_track.add_send(track)
    if route_midi:
        send.set_sws_info('I_MIDI_SRCCHAN', 0)
    while track.n_fxs > 0:
        track.fxs[0].delete()
    for i, fx in enumerate(parent_track.fxs):
        if fx.index != parent_track.instrument.index:
            fx.copy_to_track(track, index=i)
    while parent_track.n_fxs > 1:
        parent_track.fxs[-1].delete()
    return track


def save_resample_track(project: 'reapy.Project', parent_track: 'reapy.Track', resample_track: 'ResampleTrack'):
    project.set_ext_state('resample', parent_track.id, resample_track, pickled=True)
